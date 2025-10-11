package cjcj.asg

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager

import std.ast.Position
import std.collection.ArrayList
import std.collection.ArrayStack
import std.collection.Map
import std.collection.HashMap
import std.collection.Set
import std.collection.HashSet
import std.deriving.Derive

import stdx.effect.*

private class ClassAccessEffect <: Command<Unit> {
    public ClassAccessEffect(private let classAccess_: ClassReferenceForTC) { }

    public prop classAccess: ClassReferenceForTC {
        get() { classAccess_ }
    }
}

/*
* Needed to know if I can do some operations inside the current scope, for example a return
* expression.
*/
@Derive[Equatable]
public enum ScopeType {
    NIL | BLOCK | BODY
}

/*
* Needed to know if I can do some operations inside the current global type, for example use the
* "this" keyword.
*/
@Derive[Equatable]
public enum GlobalType {
    NIL | BODY
}

/*
* Gets a pointer to a root of an AST, builds the ASG, i.e. maps every reference and function call
* to the actual instance definition. To get the actual link to a function for a function call type
* checking needs to be performed. The ASG returned will have all correct links and all type assigned
*/
public class AsgMaker <: Visitor<Node> {
    public let totalClass: Environment<String, ClassReferenceForTC> = Environment()

    private var currentScopeType: ScopeType = ScopeType.NIL
    private var currentGlobalType: GlobalType = GlobalType.NIL

    // Used to know if there are cycles.
    private let nodeStatus: Map<Node, Status> = HashMap()

    /*
    * Contains the variable references with declaration type that are waiting for the next scope to
    * begin before getting declared. An example is function parameters, they need to be declared
    * inside the block and we need a way to tell him.
    */
    private let waitingDeclarations: ArrayStack<VariableReference> = ArrayStack()

    private var typeManager: TypeManager
    private var variableEnvironment: Environment<String, VariableReference> = Environment()

    private let globalTypeManager: TypeManager
    private let globalVariableEnvironment: Environment<String, VariableReference> = Environment()

    // Maps the reference to the declaration.
    private let refToDecl: Map<Reference, Decl>

    // Maps the declaration to the reference, used by declarations to know if they need to create a
    // new reference.
    private let declToRef: Map<Decl, Reference> = HashMap()
    private let declToTypeManager: Map<Decl, TypeManager> = HashMap()
    // Contains the result of a declaration if it's already been visited.
    private let result: Map<Decl, Node> = HashMap()

    // TODO: Maybe make a map of Nodes directly.
    private let nodePossibleTypes: Map<Node, Set<Type>> = HashMap()
    private let typeAssigner: TypeAssigner
    private let functionTypeGrouping: Map<Node, Map<Type, ?FuncReference>> = HashMap()

    private var currentClassRef: ?ClassReferenceForTC = None
    private var callableField: ?String = None

    /*
    * Resolves all of the function and variable references and modifies the reference to the new
    * root node of the ASG.
    */
    public init(program: Box<Program>) {
        let classTopoOrder: Array<ClassReference>
        (typeManager, classTopoOrder, refToDecl) = TypeDeclarationChecker().resolve(program.value)
        typeAssigner = TypeAssigner(
            nodePossibleTypes, totalClass, typeManager, functionTypeGrouping
        )
        globalTypeManager = typeManager

        classTopoOrder.iterator().forEach({ c =>
            totalClass.declare(c.identifier.value, ClassReferenceForTC(c))
        })

        declareGlobalScope(program.value)
        variableEnvironment = globalVariableEnvironment

        let newDecls: ArrayList<Decl> = ArrayList(program.value.decls)
        let declIndex: Map<Decl, Int64> = program.value.decls.iterator().enumerate()
            .fold(HashMap(), { acc, entry =>
                let (id, decl) = entry
                acc.add(decl, id); acc
            })

        // Visit classes in topological order, if a class is user declared visit its declaration
        // before checking for member shadowing.
        classTopoOrder.iterator().forEach({ classReference =>
            if (let Some(decl) <- refToDecl.get(classReference)) {
                let newD: Box<Decl> = Box(decl)
                try {
                    newD.value = (decl.traverse(this) as Decl).getOrThrow()
                } handle(_: ClassAccessEffect) {
                    resume
                }
                newDecls[declIndex[decl]] = newD.value
            }
            addDefaultInit(totalClass.getGlobal(classReference.identifier.value).getOrThrow())
            checkMemberShadowing(
                totalClass.getGlobal(classReference.identifier.value).getOrThrow()
            )
        })

        program.value.decls.iterator().enumerate()
            .filter({ d =>
                let (_, decl) = d
                !(decl is ClassDecl) // Don't need to traverse class again.
            })
            .map({ d =>
                let (id, decl) = d
                let newD = Box(decl)
                try {
                    newD.value = (decl.traverse(this) as Decl).getOrThrow()
                } handle(_: ClassAccessEffect) {
                    resume
                }
                (id, newD.value)
            })
            .forEach({ d => newDecls[d[0]] = d[1] })

        // Change to new ASG root.
        program.value = Program(NodeIdManager.nextId(), newDecls)
    }

    private func declareGlobalScope(program: Program): Unit {
        let globalDeclarator: Declarator = DeclaratorFactory.globalAsgDeclarator(
            globalTypeManager, globalVariableEnvironment, refToDecl, declToRef, declToTypeManager,
            { fp => (fp.traverse(this) as VariableReference).getOrThrow() },
            HashSet(Utils.fold(
                totalClass.elements.keys().iterator().filter({ k => !BUILTIN_TYPES.contains(k) }),
                ArrayList()
            ))
        )
        program.decls.iterator().forEach({ d => d.traverse(globalDeclarator) })
    }

    private func declareBodyScope(body: Body, typeManager: TypeManager,
        variableEnvironment: Environment<String, VariableReference>
    ): Unit {
        let bodyDeclarator: Declarator = DeclaratorFactory.bodyAsgDeclarator(
            variableEnvironment, typeManager, refToDecl, declToRef, declToTypeManager,
            { fp => (fp.traverse(this) as VariableReference).getOrThrow() }
        )
        body.decls.iterator().forEach({ d => d.traverse(bodyDeclarator) })
    }

    private func checkMemberShadowing(classReferenceTC: ClassReferenceForTC): Unit {
        // TODO: In the future we will check the override, open and visibility.
        if (classReferenceTC.classReference.parent.isNone()) {
            return
        }
        let variableEnvironment: Environment<String, VariableReference> =
            classReferenceTC.variableEnvironment.getOrDefault({ => Environment()})
        let classTypeManager: TypeManager = classReferenceTC.typeManager
            .getOrDefault({ => TypeManager() })

        let parent = classReferenceTC.classReference.parent.getOrThrow()
        let parentTC: ClassReferenceForTC =
            totalClass.getGlobal(parent.identifier.value).getOrThrow()

        // If it is a builtin type without attributes and function its just empty.
        let parentVariableEnvironment = parentTC.variableEnvironment
            .getOrDefault({ => Environment()})
        let parentTypeManager = parentTC.typeManager.getOrDefault({ => TypeManager() })

        variableEnvironment.elements.values().iterator().map({ v => v.identifier.value })
            .forEach({ varName =>
                if (parentVariableEnvironment.getGlobal(varName).isSome() ||
                    parentTypeManager.funcExists(varName)
                ) {
                    throw Exception("Cannot declare variables that shadows supertype members.")
                }
            })

        classTypeManager.totalFuncDef.iterator()
            .filter({ f => f[0] != "" })
            .forEach({ f =>
                let (funcName, overloads): (String, ArrayStack<FuncReference>) = f
                if (parentVariableEnvironment.getGlobal(funcName).isSome()) {
                    throw Exception("Cannot declare func that shadows supertype variable.")
                }
                overloads.iterator().forEach({ ref =>
                    if (parentTypeManager.exactFuncExistsGlobal(TypeManager.funcHashConcat(
                        funcName,  Utils.refToType(ref.paramRef.getOrThrow()))
                    )) {
                        throw Exception("Cannot declare func that shadows supertype function.")
                    }
                })
            })

        variableEnvironment.enclosing = parentVariableEnvironment
        classTypeManager.setEnclosing(parentTypeManager)
    }

    private func addDefaultInit(c: ClassReferenceForTC): Unit {
        if (c.typeManager.isNone()) {
            if (let Some(decl) <- refToDecl.get(c.classReference)) {
                decl.traverse(this)
            } else {
                c.typeManager = TypeManager()
            }
        }
        if (c.typeManager.getOrThrow().funcExists("")) {
            return ()
        }
        let ref: FuncReference = FuncReference(NodeIdManager.nextId(), Token())
        ref.effectiveType = typeManager.getType(c.classReference.identifier.value)
        ref.paramRef = ArrayList()
        c.typeManager.getOrThrow().addFunction(ref)
        nodePossibleTypes.add(ref, HashSet([ref.effectiveType.getOrThrow()]))
    }

    public override func visit(binaryExpr: BinaryExpr): Node {
        let left: Expr = (binaryExpr.left.traverse(this) as Expr).getOrThrow()
        let leftTypes: Set<Type> = nodePossibleTypes[left]

        let right: Expr = (binaryExpr.right.traverse(this) as Expr).getOrThrow()
        let rightTypes: Set<Type> = nodePossibleTypes[right]

        let typeGrouping: Map<Type, ?FuncReference> =
            typeManager.applyFunction(binaryExpr.oper.value, [leftTypes, rightTypes], None)
        if (typeGrouping.isEmpty()) {
            typeGrouping.add(all: globalTypeManager.applyFunction(binaryExpr.oper.value,
                [leftTypes, rightTypes], None))
        }

        let newBinaryExpr = BinaryExpr(NodeIdManager.nextId(), left, binaryExpr.oper, right)

        functionTypeGrouping.add(newBinaryExpr, typeGrouping)
        nodePossibleTypes.add(newBinaryExpr, HashSet(typeGrouping.keys()))

        newBinaryExpr
    }

    public override func visit(unaryExpr: UnaryExpr): Node {
        let right: Expr = (unaryExpr.right.traverse(this) as Expr).getOrThrow()
        let rightTypes: Set<Type> = nodePossibleTypes[right]

        let typeGrouping: Map<Type, ?FuncReference> =
            typeManager.applyFunction(unaryExpr.oper.value, [rightTypes], None)

        if (typeGrouping.isEmpty()) {
            typeGrouping.add(all: globalTypeManager.applyFunction(unaryExpr.oper.value,
                [rightTypes], None))
        }

        let newUnaryExpr = UnaryExpr(NodeIdManager.nextId(), unaryExpr.oper, right)

        functionTypeGrouping.add(newUnaryExpr, typeGrouping)
        nodePossibleTypes.add(newUnaryExpr, HashSet(typeGrouping.keys()))

        newUnaryExpr
    }

    public override func visit(parenExpr: ParenExpr): Node {
        let expr: Expr = (parenExpr.parenthesizedExpr.traverse(this) as Expr).getOrThrow()
        let newParenExpr = ParenExpr(NodeIdManager.nextId(), expr)

        nodePossibleTypes.add(newParenExpr, nodePossibleTypes[expr])

        newParenExpr
    }

    public override func visit(litConstExpr: LitConstExpr): Node {
        let newLitConstExpr = LitConstExpr(NodeIdManager.nextId(), litConstExpr.literal)

        nodePossibleTypes.add(newLitConstExpr, HashSet(
            match (litConstExpr.literal.kind) {
                case TokenKind.INTEGER_LITERAL => [
                    typeManager.getType("Int64"),
                    typeManager.getType("Int32"),
                    typeManager.getType("Int16"),
                    typeManager.getType("Int8"),
                    typeManager.getType("IntNative"),
                    typeManager.getType("UInt64"),
                    typeManager.getType("UInt32"),
                    typeManager.getType("UInt16"),
                    typeManager.getType("UInt8"),
                    typeManager.getType("UIntNative")
                ]
                case TokenKind.FLOAT_LITERAL => [
                    typeManager.getType("Float64"),
                    typeManager.getType("Float32"),
                    typeManager.getType("Float16")
                ]
                case TokenKind.BOOL_LITERAL => [typeManager.getType("Bool")]
                case TokenKind.STRING_LITERAL => [typeManager.getType("String")]
                case TokenKind.UNIT_LITERAL => [Type.UNIT]
                // TODO: Add all other literals.
                case _ => throw Exception("You forgot to add all the literal types")
            } // TODO: Add all supertypes.
        ))
        newLitConstExpr
    }

    public override func visit(assignExpr: AssignExpr): Node {
        let left: Expr = (assignExpr.left.traverse(this) as Expr).getOrThrow()
        let right: Expr = (assignExpr.right.traverse(this) as Expr).getOrThrow()

        let newAssignExpr = AssignExpr(NodeIdManager.nextId(), left, right)

        nodePossibleTypes.add(newAssignExpr, Type.UNIT.ancestorSet)

        newAssignExpr
    }

    public override func visit(refExpr: RefExpr): Node {
        let refExprWithRef = RefExprWithRef(NodeIdManager.nextId(), refExpr.identifier)
        var ref: ?Reference = None
        if (let Some(r) <- get(refExpr.identifier.value)) {
            ref = (r.traverse(this) as Reference).getOrThrow()
            nodePossibleTypes.add(refExprWithRef, HashSet(nodePossibleTypes[r]))
        }
        refExprWithRef.ref = ref
        refExprWithRef
    }

    public override func visit(block: Block): Node {
        let precScopeType = beginScope(ScopeType.BLOCK)

        while (let Some(last) <- waitingDeclarations.remove()) {
            declareVar(last.identifier, last)
        }

        let nodes: ArrayList<Node> = ArrayList()
        block.nodes.iterator().forEach({ n => nodes.add(n.traverse(this)) })

        endScope(precScopeType)

        let newBlock = Block(NodeIdManager.nextId(), nodes)

        nodePossibleTypes.add(newBlock, nodePossibleTypes.get(nodes.iterator().last().getOrDefault({
            => LitConstExpr(NodeIdManager.nextId(), Token(TokenKind.UNIT_LITERAL, "()", Position()))
        })).getOrDefault({ => Type.UNIT.ancestorSet }))
        
        newBlock
    }

    public override func visit(ifExpr: IfExpr): Node {
        let condition: Expr = (ifExpr.condition.traverse(this) as Expr).getOrThrow()
        let ifBlock: Block = (ifExpr.ifBlock.traverse(this) as Block).getOrThrow()
        let elseBranch: Expr = (ifExpr.elseBranch.traverse(this) as Expr).getOrThrow()

        let newIfExpr = IfExpr(NodeIdManager.nextId(), condition, ifBlock, elseBranch)

        let myTypes: Set<Type> = HashSet()
        nodePossibleTypes[ifBlock].iterator().forEach({ t1 =>
            nodePossibleTypes[elseBranch].iterator().forEach({ t2 =>
                // Add all the common supertypes of t1 and t2.
                myTypes.add(all: typeManager.smallestCommonSupertypeSet(t1, t2))
            })
        })
        nodePossibleTypes.add(newIfExpr, myTypes)
        newIfExpr
    }

    public override func visit(whileExpr: WhileExpr): Node {
        let condition: Expr = (whileExpr.condition.traverse(this) as Expr).getOrThrow()
        let whileBlock: Block = (whileExpr.block.traverse(this) as Block).getOrThrow()

        let newWhileExpr = WhileExpr(NodeIdManager.nextId(), condition, whileBlock)
        newWhileExpr.traverse(typeAssigner)

        nodePossibleTypes.add(newWhileExpr, Type.UNIT.ancestorSet)
        newWhileExpr
    }

    public override func visit(callExpr: CallExpr): Node {
        let classAccess: Box<?ClassReferenceForTC> = Box(None)
        let callee: Box<?Node> = Box(None)
        try {
            callee.value = callExpr.callee.traverse(this)
        } handle(eff: ClassAccessEffect) {
            classAccess.value = eff.classAccess
            resume
        }

        let identifier: String = callableField.getOrThrow({ =>
            Exception("Left of call expression not callable") })

        let arguments: ArrayList<Argument> = Utils.fold(
            callExpr.arguments.iterator().map({ v => (v.traverse(this) as Argument).getOrThrow() }),
            ArrayList()
        )

        let argTypes: Array<Set<Type>> = Utils.fold(arguments.iterator()
            .map({ v => nodePossibleTypes[v] }), ArrayList()).toArray()

        let funcGrouping: Map<Type, ?FuncReference> = HashMap()
        try {
            if (let Some(classAccess) <- classAccess.value) {

                if (classAccess.typeManager.isNone()) {
                    refToDecl[classAccess.classReference].traverse(this)
                }
                funcGrouping.add(all: classAccess.typeManager.getOrThrow()
                    .applyFunction(identifier, argTypes, None))
            } else {
                funcGrouping.add(all: typeManager.applyFunction(identifier, argTypes, None))
                if (funcGrouping.isEmpty()) {
                    funcGrouping.add(all: globalTypeManager.applyFunction(identifier, argTypes, None))
                    if (funcGrouping.isEmpty()) {
                        throw Exception("Impossible to find a function to call")
                    }
                }
            }
        } handle(eff: TypeEffect) {
            eff.ref.traverse(this)
            resume with eff.ref.effectiveType.getOrThrow()
        }
        callableField = None

        let callExprWithRef = CallExprWithRef(NodeIdManager.nextId(), callee.value.getOrThrow(),
            arguments)
        functionTypeGrouping.add(callExprWithRef, funcGrouping)
        nodePossibleTypes.add(callExprWithRef, HashSet(funcGrouping.keys()))

        callExprWithRef
    }

    public override func visit(returnExpr: ReturnExpr): Node {
        if (currentScopeType == ScopeType.BLOCK) {
            let expr: ?Expr = if (let Some(expr) <- returnExpr.expr) {
                expr.traverse(this) as Expr
            } else {
                None
            }

            let newReturnExpr = ReturnExpr(NodeIdManager.nextId(), expr, returnExpr.keyword)
            nodePossibleTypes.add(newReturnExpr, HashSet([Type.NOTHING]))
            return newReturnExpr
        }
        println("Return statement not inside a function")
        throw ReturnExprError()
    }

    public override func visit(jumpExpr: JumpExpr): Node {
        if (currentScopeType == ScopeType.BLOCK) {
            return JumpExpr(NodeIdManager.nextId(), jumpExpr.keyword)
        }

        println("Jump statement not side a block")
        throw Exception()
    }

    public override func visit(varDecl: VarDecl): Node {
        if (let Some(status) <- nodeStatus.get(varDecl)) {
            match (status) {
                case Status.IN => throw Exception("Could not infer the type of " +
                    "${varDecl.identifier.value}")
                case Status.VIS => return result[varDecl]
            }
        }
        nodeStatus.add(varDecl, Status.IN)

        var toDeclare: Bool = false

        let reference: VariableReference
        if (let Some(ref) <- declToRef.get(varDecl)) {
            reference = (ref as VariableReference).getOrThrow()
        } else {
            if (currentScopeType == ScopeType.BODY) {
                reference = variableEnvironment.getLocal(varDecl.identifier.value).getOrThrow({ =>
                    Exception("Variable should've been declared in body scope") })
            } else {
                reference = VariableReference(NodeIdManager.nextId(), varDecl.identifier,
                    varDecl.keyword)
                toDeclare = true
            }
            refToDecl.add(reference, varDecl)
            declToRef.add(varDecl, reference)
        }

        // Call the initializer first because there could be reference to previous variables with
        // the same identifier.
        var initializer: ?Expr = None
        if (let Some(initzer) <- varDecl.initializer) {
            initializer = initzer.traverse(this) as Expr
            nodePossibleTypes.add(reference, nodePossibleTypes[initializer.getOrThrow()])
        }

        var declType: ?TypeNode = None
        if (let Some(dt) <- varDecl.declType) {
            declType = dt.traverse(this) as TypeNode
            nodePossibleTypes.addIfAbsent(reference,
                HashSet([declType.getOrThrow().traverse(typeAssigner)]))
        }

        if (toDeclare) {
            declareVar(varDecl.identifier, reference)
        }
        nodeStatus.add(varDecl, Status.VIS)

        let varDeclWithRef: VarDeclWithRef = VarDeclWithRef(NodeIdManager.nextId(), varDecl.keyword,
            varDecl.identifier, reference, initializer, declType)

        nodePossibleTypes.add(varDeclWithRef, HashSet([varDeclWithRef.traverse(typeAssigner)]))

        result[varDecl] = varDeclWithRef
        varDeclWithRef
    }

    public override func visit(funcParam: FuncParam): Node {
        let paramType: TypeNode = (funcParam.paramType.traverse(this) as TypeNode).getOrThrow()
        let ref: VariableReference = VariableReference(NodeIdManager.nextId(),
            funcParam.paramType.typeParameterName, Token(TokenKind.LET, "let", Position()))
        ref.effectiveType = paramType.traverse(typeAssigner)
        ref
    }

    public override func visit(funcDecl: FuncDecl): Node {
        let precTypeManager: TypeManager = typeManager
        typeManager = if (let Some(declTypeManager) <- declToTypeManager.get(funcDecl)) {
            declTypeManager
        } else {
            typeManager
        }
        if (let Some(status) <- nodeStatus.get(funcDecl)) {
            match(status) {
                case Status.IN => throw Exception("Could not infer the type of " +
                    "${funcDecl.identifier.value}")
                case Status.VIS => return result[funcDecl]
            }
        }
        nodeStatus.add(funcDecl, Status.IN)

        let reference: FuncReference

        if (let Some(ref) <- declToRef.get(funcDecl)) {
            reference = (ref as FuncReference).getOrThrow()
        } else {
            let funcHashConcat: String = TypeManager.funcHashConcat(
                funcDecl.identifier.value,
                Utils.fold(
                    funcDecl.params.iterator().map({ p => p.paramType.typeName.value }),
                    ArrayList()
                ).toArray()
            )
            if (typeManager.isGlobal || currentScopeType == ScopeType.BODY) {
                reference = typeManager.immediateFuncDef.get(funcHashConcat).getOrThrow({ =>
                    Exception("Global or body func should've been declared in advance")})
            } else {
                reference = FuncReference(NodeIdManager.nextId(), funcDecl.identifier)
                let paramRefs: ArrayList<VariableReference> = ArrayList()
                reference.paramRef = Utils.funcParamToParamRef(funcDecl.params, typeManager,
                    { fp => (fp.traverse(this) as VariableReference).getOrThrow() })
            }

            refToDecl.add(reference, funcDecl)
            declToRef.add(funcDecl, reference)
        }

        // Set effective type to parameters (= to declaration type)
        reference.paramRef.getOrThrow().iterator().enumerate().forEach({ v =>
            v[1].effectiveType = funcDecl.params[v[0]].paramType.traverse(typeAssigner)
        })

        // Declare function if it is not already declared.
        if (declToTypeManager.get(funcDecl).isNone()) {
            typeManager.addFunction(reference)
        }

        var declType: ?TypeNode = None
        if (let Some(dt) <- funcDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }

        reference.paramRef.getOrThrow().iterator().forEach({ r => waitingDeclarations.add(r) })
        let block: Block = (funcDecl.block.traverse(this) as Block).getOrThrow()

        let funcDeclWithRef: FuncDeclWithRef = FuncDeclWithRef(NodeIdManager.nextId(),
            funcDecl.keyword, funcDecl.identifier, block, funcDecl.params, declType, reference)

        nodePossibleTypes.add(funcDeclWithRef, HashSet([funcDeclWithRef.traverse(typeAssigner)]))

        typeManager = precTypeManager

        nodeStatus.add(funcDecl, Status.VIS)

        result[funcDecl] = funcDeclWithRef

        funcDeclWithRef
    }

    public override func visit(mainDecl: MainDecl): Node {
        let reference: MainReference = MainReference(NodeIdManager.nextId())
        if (let Some(param) <- mainDecl.param) {
            let paramRef: VariableReference =
                (param.traverse(this) as VariableReference).getOrThrow()
            waitingDeclarations.add(paramRef)
            reference.paramRef = paramRef
            paramRef.effectiveType = param.traverse(typeAssigner)
        }

        var declType: ?TypeNode = None
        if (let Some(dt) <- mainDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }

        let block: Block = (mainDecl.block.traverse(this) as Block).getOrThrow()

        let mainDeclWithRef: MainDeclWithRef = MainDeclWithRef(NodeIdManager.nextId(), block,
            mainDecl.param, declType, reference)

        nodePossibleTypes.add(mainDeclWithRef, HashSet([mainDeclWithRef.traverse(typeAssigner)]))
        mainDeclWithRef
    }

    public override func visit(argument: Argument): Node {
        let expr: Node = argument.expr.traverse(this)

        let newArgument = Argument(NodeIdManager.nextId(), expr)

        nodePossibleTypes.add(newArgument, nodePossibleTypes[expr])

        newArgument
    }

    public override func visit(primitiveType: PrimitiveType): Node {
        let newPrimitiveType = PrimitiveType(NodeIdManager.nextId(),
            primitiveType.typeParameterName, primitiveType.typeName)

        nodePossibleTypes.add(newPrimitiveType, HashSet([primitiveType.traverse(typeAssigner)]))

        newPrimitiveType
    }

    public override func visit(refType: RefType): Node {
        if(!isTypeDeclared(refType.typeName)) {
            throw Exception("Type is not declared")
        }
        let newRefType = RefType(NodeIdManager.nextId(), refType.typeParameterName,
            refType.typeName)

        nodePossibleTypes.add(newRefType, HashSet([refType.traverse(typeAssigner)]))

        newRefType
    }

    public override func visit(classDecl: ClassDecl): Node {
        currentClassRef = totalClass.getLocal(classDecl.identifier.value)
            .getOrThrow({ => Exception("ClassReference should've been declared in advance") })
        typeAssigner.currentClassRef = currentClassRef
        currentClassRef.getOrThrow().classReference.effectiveType =
            typeManager.getType(classDecl.identifier.value)

        let body = (classDecl.body.traverse(this) as Body).getOrThrow()

        let superTypes = ArrayList<TypeNode>()
        classDecl.superTypes.iterator().forEach({ superType =>
            let visitedSuperType = (superType.traverse(this) as TypeNode).getOrThrow()
            superTypes.add(visitedSuperType)
        })
        let classDeclWithRef: ClassDeclWithRef = ClassDeclWithRef(
            NodeIdManager.nextId(), classDecl.keyword, classDecl.identifier, body, superTypes,
            currentClassRef.getOrThrow().classReference
        )

        classDeclWithRef.ref.effectiveType = typeManager.getType(classDeclWithRef.identifier.value)
        currentClassRef = None

        typeAssigner.currentClassRef = currentClassRef

        classDeclWithRef
    }

    public override func visit(varReference: VariableReference): Node {
        if (let Some(effectiveType) <- varReference.effectiveType) {
            nodePossibleTypes.add(varReference, HashSet([effectiveType]))
            return varReference
        }
        let decl: Decl = refToDecl.get(varReference).getOrThrow()
        if (let Some(declType) <- decl.declType) {
            let tp: Type = declType.traverse(typeAssigner)
            nodePossibleTypes.add(varReference, HashSet([tp]))
            return varReference
        }
        (decl.traverse(this) as VarDeclWithRef).getOrThrow().ref
    }

    public override func visit(classReference: ClassReference): Node {
        if (let Some(effective) <- classReference.effectiveType) {
            nodePossibleTypes.add(classReference, HashSet([effective]))
        } else {
            let tp: Type = typeManager.getType(classReference.identifier.value)
            classReference.effectiveType = tp
            nodePossibleTypes.add(classReference, HashSet([tp]))
        }
        callableField = ""
        perform ClassAccessEffect(totalClass.getLocal(classReference.identifier.value).getOrThrow())
        classReference
    }

    public override func visit(funcReference: FuncReference): Node {
        if (let Some(effectiveType) <- funcReference.effectiveType) {
            nodePossibleTypes.add(funcReference, HashSet([effectiveType]))
        } else {
            let decl = refToDecl[funcReference]
            // If there is declaration type I assign it.
            if (let Some(declType) <- decl.declType) {
                let tp: Type = declType.traverse(typeAssigner)
                nodePossibleTypes.add(funcReference, HashSet([tp]))
                funcReference.effectiveType = tp
            } else { // Otherwise I have to visit the declaration that will assign the type.
                decl.traverse(this)
                nodePossibleTypes.add(funcReference,
                    HashSet([funcReference.effectiveType.getOrThrow()]))
            }
        }
        callableField = funcReference.identifier.value
        funcReference
    }

    public override func visit(body: Body): Node {
        let precGlobalType: GlobalType = beginGlobal(GlobalType.BODY)

        let precScopeType: ScopeType = currentScopeType
        currentScopeType = ScopeType.BODY

        let currentClassRef: ClassReferenceForTC = currentClassRef.getOrThrow()
        currentClassRef.typeManager = TypeManager(typeManager)
        currentClassRef.variableEnvironment = Environment()

        declareBodyScope(body, currentClassRef.typeManager.getOrThrow(),
            currentClassRef.variableEnvironment.getOrThrow())

        addDefaultInit(currentClassRef)
        checkMemberShadowing(currentClassRef)

        let precTypeManager = typeManager
        let precVarEnv = variableEnvironment

        typeManager = currentClassRef.typeManager.getOrThrow()
        variableEnvironment = currentClassRef.variableEnvironment.getOrThrow()

        let decls: ArrayList<Decl> = ArrayList()
        body.decls.iterator().forEach({ d => decls.add((d.traverse(this) as Decl).getOrThrow()) })

        endGlobal(precGlobalType)
        typeManager = precTypeManager
        variableEnvironment = precVarEnv
        currentScopeType = precScopeType

        Body(NodeIdManager.nextId(), decls)
    }

    // TODO: Remember to change this when we add other class-like structures.
    public override func visit(memberAccess: MemberAccess): Node {
        let baseExpr: Node = memberAccess.baseExpr.traverse(this)

        let memberAccessWithRef: MemberAccessWithRef = MemberAccessWithRef(NodeIdManager.nextId(),
            baseExpr, memberAccess.field)

        // The baseExpr of a member access needs to be solved before calling the field, the class
        // found does not depend on the field.
        let classType: Type = memberAccessWithRef.baseExpr.traverse(typeAssigner)

        let baseClass: ClassReferenceForTC = totalClass.getGlobal(classType.name)
                .getOrThrow({ => Exception("Base of member access is not a class!") })

        let field: String = memberAccessWithRef.field.value
        let (tp, isCallable) = if (let Some(member) <- baseClass.getMember(field)) {
            member
        } else {
            totalClass.getGlobal(baseClass.classReference.parent.getOrThrow({ => Exception(
                "${field} does not exist in ${baseClass.classReference.identifier.value}" +
                "And ${baseClass.classReference.identifier.value} has no parent class"
            )}).identifier.value).getOrThrow().getMember(field).getOrThrow({ =>
                Exception("${field} does not exist in ${baseClass.classReference.identifier.value}")
            })
        }
        if (isCallable) {
            callableField = field
        }

        memberAccessWithRef.ref = baseClass.classReference
        nodePossibleTypes.add(memberAccessWithRef, HashSet([tp]))
        perform ClassAccessEffect(
            totalClass.getLocal(baseClass.classReference.identifier.value).getOrThrow()
        )
        memberAccessWithRef
    }

    public override func visit(thisSuperExpr: ThisSuperExpr): Node {
        let thisSuperReference: ThisSuperReference = ThisSuperReference(NodeIdManager.nextId(),
            thisSuperExpr.keyword)

        if (currentGlobalType != GlobalType.BODY) {
            throw Exception("Cannot invoke ${thisSuperExpr.keyword.value} outside of a class")
        }

        let classReference: ClassReference = currentClassRef.getOrThrow({ =>
            Exception("Cannot have ${thisSuperReference.keyword.value} outside of a class")})
            .classReference

        thisSuperReference.classReference = classReference
        callableField = ""
        if (thisSuperReference.keyword.kind == TokenKind.THIS) {
            nodePossibleTypes.add(thisSuperReference,
                HashSet([classReference.effectiveType.getOrThrow()]))
            return thisSuperReference
        }

        nodePossibleTypes.add(thisSuperReference, HashSet([classReference.parent.getOrThrow({ =>
            Exception("Cannot invoke super without super type")}).effectiveType.getOrThrow()]))

        thisSuperReference
    }

    private func beginGlobal(newGlobalType: GlobalType): GlobalType {
        let precGlobalType: GlobalType = currentGlobalType
        currentGlobalType = newGlobalType
        precGlobalType
    }

    private func endGlobal(precGlobalType: GlobalType): Unit {
        currentGlobalType = precGlobalType
    }

    private func beginScope(newScopeType: ScopeType): ScopeType{
        let precScopeType: ScopeType = currentScopeType
        currentScopeType = newScopeType
        variableEnvironment = Environment(variableEnvironment)
        typeManager = TypeManager(typeManager)
        precScopeType
    }

    private func endScope(precScopeType: ScopeType): Unit {
        currentScopeType = precScopeType
        variableEnvironment = variableEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
        typeManager = typeManager.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
    }

    private func declareVar(identifier: Token, value: VariableReference): Unit {
        variableEnvironment.declare(identifier.value, value)
    }

    private func isTypeDeclared(typeName: Token): Bool {
        totalClass.getGlobal(typeName.value).isSome()
    }

    // Update the callableField field according to what's the closest link of identifier and return
    // a link if certain that the link is correct.
    private func get(identifier: String): ?Reference {
        var tmpTypeManager: TypeManager = typeManager
        var tmpVarEnv: Environment<String, VariableReference> = variableEnvironment
        while (!tmpTypeManager.isGlobal && !tmpVarEnv.isGlobal) {
            if (tmpTypeManager.funcExists(identifier)) {
                callableField = identifier
                // I don't know what exact function I'm calling.
                return None
            }
            if (let Some(va) <- tmpVarEnv.getLocal(identifier)) {
                return va
            }
            tmpTypeManager = tmpTypeManager.enclosing.getOrThrow()
            tmpVarEnv = tmpVarEnv.enclosing.getOrThrow()
        }
        if (tmpTypeManager.funcExists(identifier)) {
            callableField = identifier
            // I don't know what exact function I'm calling.
            return None
        }
        if (let Some(va) <- tmpVarEnv.getLocal(identifier)) {
            return va
        }

        // Check the global scope
        if (let Some(clas) <- totalClass.getLocal(identifier)) {
            return clas.classReference
        }
        if (globalTypeManager.funcExists(identifier)) {
            callableField = identifier
            return None
        }
        if (let Some(va) <- globalVariableEnvironment.getLocal(identifier)) {
            return va
        }
        throw Exception("${identifier} is undefined.")
    }
}

