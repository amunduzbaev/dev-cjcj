package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.asg.ScopeType
import cjcj.asg.TypeManager
import cjcj.asg.Declarator
import cjcj.asg.DeclaratorFactory
import cjcj.parser.NodeIdManager
import cjcj.scanner.Token

import std.ast.Position
import std.collection.*

/*
* It will check that all the operation types and assignments are correct based on the types of the
* elements and based on the defined operations.
*/
public class TypeChecker <: Visitor<Type> {
    // Used to know if there are cycles.
    private let referenceStatus: Map<Reference, Status> = HashMap()
    // Maps the reference to the declaration.
    private let funcToDecl: Map<Reference, FuncDeclWithRef> = HashMap()

    private let typeManager: TypeManager
    private let expectedReturnType: ArrayStack<Type> = ArrayStack()
    private var scopeType: ScopeType = ScopeType.NIL
    private var classEnvironment: Environment<String, ClassReferenceForTC> = Environment()
    private var currentClassRef: ?ClassReferenceForTC = None

    // Contains the name of the last callable field if there is some.
    private var callableField: ?String = None


    public init(program: Program) {
        // TODO: Make declaration checker return the topological order of the classes, it's needed
        // for member shadowing check.
        // Declare every type.
        typeManager = TypeDeclarationChecker().resolve(program)

        let tmpClassEnvironment: Environment<String, ClassReference> = Environment()
        declareBuiltinClassReferences(tmpClassEnvironment)

        let globalAsgDeclarator: Declarator = DeclaratorFactory.globalAsgDeclarator(
            tmpClassEnvironment, typeManager
        )
        program.decls.iterator().forEach({ d => d.traverse(globalAsgDeclarator) })
        tmpClassEnvironment.elements.iterator()
            .forEach({ cr => classEnvironment.declare(cr[0], ClassReferenceForTC(cr[1])) })

        program.traverse(GlobalBodyTypeAssigner(classEnvironment, typeManager, funcToDecl))
        program.traverse(this)
    }

    private func declareBuiltinClassReferences(
        classEnvironment: Environment<String, ClassReference>
    ) {
        BUILTIN_TYPES.iterator().forEach({ t =>
            classEnvironment.declare(
                t[0],
                ClassReference(NodeIdManager.nextId(), Token(TokenKind.ILLEGAL, t[0], Position()))
            )
        })
    }

    public override func visit(program: Program): Type {
        program.decls.iterator().forEach({ d => d.traverse(this) })
        Type.DUMMY
    }

    public override func visit(binaryExpr: BinaryExpr): Type {
        let left: Type = binaryExpr.left.traverse(this)
        let right: Type = binaryExpr.right.traverse(this)
        typeManager.applyFunction(binaryExpr.oper.value, [left, right], expectedReturnType.peek())
            .effectiveType.getOrThrow()
    }

    public override func visit(unaryExpr: UnaryExpr): Type {
        let right: Type = unaryExpr.right.traverse(this)
        typeManager.applyFunction(unaryExpr.oper.value, [right], expectedReturnType.peek())
            .effectiveType.getOrThrow()
    }

    public override func visit(parenExpr: ParenExpr): Type {
        parenExpr.parenthesizedExpr.traverse(this)
    }

    public override func visit(litConstExpr: LitConstExpr): Type {
        match (litConstExpr.literal.kind) {
            // TODO: Change this, compiler can do implicit cast.
            case TokenKind.INTEGER_LITERAL => return typeManager.getType("Int64")
            case TokenKind.FLOAT_LITERAL => return typeManager.getType("Float64")
            case TokenKind.BOOL_LITERAL => return typeManager.getType("Bool")
            case TokenKind.STRING_LITERAL => return typeManager.getType("String")
            case TokenKind.UNIT_LITERAL => return typeManager.getType("Unit")
            // TODO: Add all other literals.
            case _ => return Type.DUMMY
        }
    }

    public override func visit(assignExpr: AssignExpr): Type {
        let left: Type = assignExpr.left.traverse(this)

        expectedReturnType.add(left)

        let right: Type = assignExpr.right.traverse(this)
        if (!left.isParent(right)) {
            throw Exception("Cannot assign ${right.name} to ${left.name}")
        }

        expectedReturnType.remove()
        typeManager.getType("Unit")
    }

    public override func visit(block: Block): Type {
        beginScope()

        let lastId = block.nodes.last.getOrDefault({ => Expr() }).id
        let returnType = block.nodes.iterator()
            .map({ n => (n, n.traverse(this)) })
            .filter({ n => n[0] is ReturnExpr || n[0].id == lastId })
            .map({ n => n[1] })
            .reduce({ a,b => typeManager.smallestCommonSupertype(a, b) })
            .getOrDefault({ => typeManager.getType("Unit")})

        endScope()
        returnType
    }

    /*
    * Here we want to find the lowest common supertype of all the branches, if an ifExpr doesn't
    * have an else branch then the return type is Unit.
    */
    public override func visit(ifExpr: IfExpr): Type {
        if (ifExpr.condition.traverse(this) != typeManager.getType("Bool")) {
            throw Exception("If condition must be bool.")
        }
        let ifType: Type = ifExpr.ifBlock.traverse(this)
        let elseType: Type = ifExpr.elseBranch.traverse(this)
        return typeManager.smallestCommonSupertype(ifType, elseType)
    }

    public override func visit(whileExpr: WhileExpr): Type {
        if (whileExpr.condition.traverse(this) != typeManager.getType("Bool")) {
            throw Exception("While condition must be bool.")
        }
        whileExpr.block.traverse(this)
        typeManager.getType("Unit")
    }

    public override func visit(returnExpr: ReturnExpr): Type {
        if (let Some(expr) <- returnExpr.expr) {
            return expr.traverse(this)
        }
        typeManager.getType("Unit")
    }

    public override func visit(funcParam: FuncParam): Type {
        funcParam.paramType.traverse(this)
    }

    public override func visit(argument: Argument): Type {
        argument.expr.traverse(this)
    }

    public override func visit(primitiveType: PrimitiveType): Type {
        typeManager.getType(primitiveType.typeName.value)
    }

    public override func visit(refType: RefType): Type {
        typeManager.getType(refType.typeName.value)
    }

    public override func visit(varDeclWithRef: VarDeclWithRef): Type {
        let ref: Reference = varDeclWithRef.ref
        if (let Some(status) <- referenceStatus.get(ref)) {
            match (status) {
                case Status.IN => throw Exception("Could not infer the type of " +
                    "${ref.identifier.value}")
                case Status.VIS => return ref.effectiveType.getOrThrow()
            }
        }
        referenceStatus.add(ref, Status.IN)

        var targetType: ?Type = if (let Some(effectiveType) <- ref.effectiveType) {
            effectiveType
        } else if (let Some(declType) <- varDeclWithRef.declType) {
            declType.traverse(this)
        } else {
            None
        }

        let infType: ?Type = if (let Some(initzer) <- varDeclWithRef.initializer) {
            initzer.traverse(this)
        } else {
            None
        }

        if (let Some(targetType) <- targetType) {
            if (let Some(infType) <- infType && !targetType.isParent(infType)) {
                throw Exception("Assigned type not correct, expected ${targetType.name} " +
                    "found ${infType.name}")
            }
        } else if (let Some(infType) <- infType) {
            targetType = infType
        } else {
            throw Exception("Impossible to infer the type of ${ref.identifier.value}, there must " +
                "be an initializer if there is no declaration type.")
        }

        referenceStatus.add(ref, Status.VIS)
        ref.effectiveType = targetType
        typeManager.getType("Unit")
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): Type {
        let ref: FuncReference = funcDeclWithRef.funcRef
        if (let Some(status) <- referenceStatus.get(ref) && status == Status.IN) {
            throw Exception("Could not infer the type of ${ref.identifier.value}")
        }
        referenceStatus.add(ref, Status.IN)

        if (funcDeclWithRef.keyword.kind == TokenKind.INIT) {
            
            funcDeclWithRef.block.traverse(this)
            
        } else {

            let infType: Type = funcDeclWithRef.block.traverse(this)
            var targetType: Type = if (let Some(effectiveType) <- ref.effectiveType) {
                effectiveType
            } else if (let Some(declType) <- funcDeclWithRef.declType) {
                declType.traverse(this)
            } else {
                infType
            }

            if (!targetType.isParent(infType)) {
                throw Exception("Type of function not correct, expected ${targetType.name}" +
                    ", found: ${infType.name}")
            }

            ref.effectiveType = targetType
        }
        
        // If I'm in global or body scope everything is already declared.
        if (!typeManager.isGlobal && scopeType != ScopeType.BODY) {
            typeManager.addFunction(ref)
        }

        referenceStatus.add(ref, Status.VIS)
        typeManager.getType("Unit")
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): Type {
        let ref: MainReference = mainDeclWithRef.mainRef

        let infType: Type = mainDeclWithRef.block.traverse(this)
        var targetType: Type = if (let Some(effectiveType) <- ref.effectiveType) {
            effectiveType
        } else if (let Some(declType) <- mainDeclWithRef.declType) {
            declType.traverse(this)
        } else {
            infType
        }
        
        if (!targetType.isParent(infType)) {
            throw Exception("Type of main function not correct, expected ${targetType.name}" +
                ", found: ${infType.name}")
        }

        ref.effectiveType = targetType
        typeManager.getType("Unit")
    }

    public override func visit(varReference: VariableReference): Type {
        // TODO: make it callable if lambda in the future.
        varReference.effectiveType.getOrThrow()
    }

    public override func visit(classReference: ClassReference): Type {
        callableField = ""
        classReference.effectiveType.getOrThrow()
    }

    public override func visit(funcReference: FuncReference): Type{
        let res: Type
        if (let Some(effectiveType) <- funcReference.effectiveType) {
            res = effectiveType
        } else {
            res = funcToDecl.get(funcReference).getOrThrow().traverse(this)
        }
        callableField = funcReference.identifier.value
        res
    }

    public override func visit(refExprWithRef: RefExprWithRef): Type {
        refExprWithRef.ref.traverse(this)
    }

    public override func visit(callExprWithRef: CallExprWithRef): Type {
        let typeManager: TypeManager = if (let Some(currentClassRef) <- currentClassRef) {
            currentClassRef.typeManager.getOrThrow()
        } else {
            typeManager
        }

        let tp: Type = callExprWithRef.callee.traverse(this)
        let identifier: String = callableField.getOrThrow({ =>
            Exception("Left of call expression not callable") })
        let params = callExprWithRef.arguments.iterator().fold<ArrayList<Type>>(ArrayList(),
                    { res, v => res.add(v.traverse(this)); res }).toArray()

        var ref: FuncReference
        // Check first for a function call.
        try {
            ref = typeManager.applyFunction(identifier, params, expectedReturnType.peek())
        } catch(e: Exception) {
            if (let Some(classRef) <- classEnvironment.getGlobal(tp.name)) {
                ref = classRef.typeManager.getOrThrow()
                    .applyFunction(identifier, params, expectedReturnType.peek())
            } else {
                throw e
            }
        }

        callableField = None

        // Set the reference to the real one.
        callExprWithRef.ref = ref
        ref.effectiveType.getOrThrow()
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): Type {
        let classRefForTC = classEnvironment.getGlobal(classDeclWithRef.ref.identifier.value)
            .getOrThrow({ => Exception("Unexpected, class should've been declared")})

        checkMemberShadowing(classRefForTC)
        currentClassRef = classRefForTC

        classDeclWithRef.body.traverse(this)

        currentClassRef = None
        typeManager.getType("Unit")
    }

    public override func visit(body: Body): Type {
        scopeType = ScopeType.BODY

        body.decls.iterator().forEach({ decl => decl.traverse(this) })

        scopeType = ScopeType.NIL
        Type.DUMMY
    }

    public override func visit(memberAccess: MemberAccess): Type {
        // TODO: Remember to change this when we add other class-like structures.
        var baseClass: ClassReferenceForTC =
            classEnvironment.getGlobal((memberAccess.baseExpr.traverse(this).name))
                .getOrThrow({ => Exception("Base of member access is not a class!") })
        let field: String = memberAccess.field.value
        let (tp, isCallable) = getMemberType(baseClass, field)
        if (isCallable) {
            callableField = field
        }
        return tp
    }

    /*
    * Goes up to the supertypes until it finds the member, returns if the field is callable and its
    * type.
    */
    private func getMemberType(baseClass: ClassReferenceForTC, field: String): (Type, Bool) {
        var currClass = baseClass
        while (let Some(parent) <- currClass.classReference.parent) {
            if (let Some((tp, isCallable)) <- currClass.getMember(field)) {
                return (tp, isCallable)
            }
            currClass = classEnvironment.getGlobal(parent.identifier.value).getOrThrow({ =>
                Exception("Parent class is not declared!")})
        }
        if (let Some((tp, isCallable)) <- currClass.getMember(field)) {
            return (tp, isCallable)
        }
        throw Exception("${field} is not defined in ${baseClass.classReference.identifier.value}")
    }

    private func beginScope(): Unit {
        typeManager.beginScope()
    }

    private func endScope(): Unit {
        typeManager.endScope()
    }

    private func checkMemberShadowing(classReferenceTC: ClassReferenceForTC): Unit {
        // TODO: In the future we will check the override, open and visibility.
        if (classReferenceTC.classReference.parent.isNone()) {
            return
        }
        let variableEnvironment: Environment<String, VariableReference> =
            classReferenceTC.variableEnvironment.getOrThrow()
        let classTypeManager: TypeManager = classReferenceTC.typeManager.getOrThrow()

        let parent = classReferenceTC.classReference.parent.getOrThrow()
        let parentTC: ClassReferenceForTC =
            classEnvironment.getGlobal(parent.identifier.value).getOrThrow()
        // If it is a builtin type without attributes and function its just empty.
        let parentVariableEnvironment = parentTC.variableEnvironment.getOrDefault({ => Environment()})
        let parentTypeManager = parentTC.typeManager.getOrDefault({ => TypeManager() })

        for (varDecl in variableEnvironment.elements.values()) {
            let varName: String = varDecl.identifier.value
            if (parentVariableEnvironment.getGlobal(varName).isSome() ||
                parentTypeManager.funcExists(varName)
            ) {
                throw Exception("Cannot declare variables that shadows supertype members.")
            }
        }
        for (funcName in classTypeManager.totalFuncEnvironment.elements.keys()) {
            if (parentVariableEnvironment.getGlobal(funcName).isSome() ||
                parentTypeManager.funcExists(funcName)
            ) {
                throw Exception("Cannot declare func that shadows supertype members.")
            }
        }

        variableEnvironment.enclosing = parentVariableEnvironment
        classTypeManager.setEnclosing(parentTypeManager)
    }

    public override func visit(thisSuperReference: ThisSuperReference): Type {
        let classReference: ClassReference = currentClassRef.getOrThrow({ =>
            Exception("Cannot have ${thisSuperReference.keyword.value} outside of a class")})
            .classReference 
        thisSuperReference.classReference = classReference
        callableField = ""
        if (thisSuperReference.keyword.kind == TokenKind.THIS) {
            return classReference.effectiveType.getOrThrow()
        }
        classReference.parent.getOrThrow({ =>
            Exception("Cannot invoke super without super type")}).effectiveType.getOrThrow()
    }
}