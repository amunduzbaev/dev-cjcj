package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.scanner.Token
import cjcj.asg.ScopeType
import cjcj.asg.TypeManager
import cjcj.asg.Declarator
import cjcj.asg.DeclaratorFactory

import std.collection.*

/*
* Visitor that will assign all the types to all the references. When it's visiting a reference it
* will see if there is a declaration type, in that case it will just assume that it's correct and it
* will assign it as the effective type. If the type is not defined it will infer it from the context
* that can be an assignment for variables or the type of the block for a function definition.
*/
public class TypeAssigner <: Visitor<Type> {
    // Dummy type to return when I don't need to return an actual one.
    private static let DUMMY_TYPE = Type("")
    private let expectedReturnType: ArrayStack<Type> = ArrayStack()
    // Used to know if there are cycles.
    private let referenceStatus: Map<Reference, Status> = HashMap()

    // Contains the name of the last callable field if there is some.
    private var callableField: ?String = None
    private var currentClass: ?ClassReferenceForTC = None
    private var scopeType: ScopeType = ScopeType.NIL
    private var inConstructor: Bool = false

    /*
    * It expects already to have every class declared and a typeManager to query and insert
    * new functions that are not declared in the global scope.
    */
    public TypeAssigner(
        program: Program, private var classEnvironment: Environment<String, ClassReferenceForTC>,
        private let typeManager: TypeManager
    ) {
        program.traverse(this)
    }

    public init(
        classEnvironment: Environment<String, ClassReferenceForTC>, typeManager: TypeManager
    ) {
        this.classEnvironment = classEnvironment
        this.typeManager = typeManager
    }

    public override func visit(program: Program): Type {
        program.decls.iterator().forEach({ d => d.traverse(this) })
        DUMMY_TYPE
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
            case TokenKind.INTEGER_LITERAL => return typeManager.getType("Int64")
            case TokenKind.FLOAT_LITERAL => return typeManager.getType("Float64")
            case TokenKind.BOOL_LITERAL => return typeManager.getType("Bool")
            case TokenKind.STRING_LITERAL => return typeManager.getType("String")
            case TokenKind.UNIT_LITERAL => return typeManager.getType("Unit")
            // TODO: Add all other literals.
            case _ => return DUMMY_TYPE
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
        typeManager.beginScope()

        let lastId = block.nodes.last.getOrDefault({ => Expr() }).id
        // TODO: Unroll and make it faster.
        let returnType = block.nodes.iterator()
            .map({ n => (n, n.traverse(this)) })
            .filter({ n => n[0] is ReturnExpr || n[0].id == lastId })
            .map({ n => n[1] })
            .reduce({ a,b => typeManager.smallestCommonSupertype(a, b) })
            .getOrDefault({ => typeManager.getType("Unit")})

        typeManager.endScope()
        returnType
    }

    /*
    * Here we want to find the lowest common supertype of all the branches.
    */
    public override func visit(ifExpr: IfExpr): Type {
        ifExpr.condition.traverse(this)
        let ifType: Type = ifExpr.ifBlock.traverse(this)
        let elseType: Type = ifExpr.elseBranch.traverse(this)
        return typeManager.smallestCommonSupertype(ifType, elseType)
    }

    public override func visit(whileExpr: WhileExpr): Type {
        whileExpr.condition.traverse(this)
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
        if (let Some(status) <- referenceStatus.get(ref) && status == Status.IN) {
            throw Exception("Could not infer the type of ${ref.identifier.value}")
        }

        if (let Some(t) <- varDeclWithRef.declType) {
            referenceStatus.add(ref, Status.VIS)
            ref.effectiveType = t.traverse(this)
            return typeManager.getType("Unit")
        }

        referenceStatus.add(ref, Status.IN)
        let initzer: Expr = varDeclWithRef.initializer.getOrThrow({ =>
            Exception("No initializer and no declType in typeChecking, should've been checked" +
                " before") })
        
        let initType: Type = initzer.traverse(this)
        ref.effectiveType = initType
        referenceStatus.add(ref, Status.VIS)
        typeManager.getType("Unit")
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): Type {
        let ref: FuncReference = funcDeclWithRef.funcRef
        if (let Some(status) <- referenceStatus.get(ref) && status == Status.IN) {
            throw Exception("Could not infer the type of ${ref.identifier.value}")
        }

        let params = funcDeclWithRef.params
        // Set effective type to parameters (= to declaration type)
        ref.paramRef.getOrThrow().iterator().enumerate()
            .forEach({ v => v[1].effectiveType = params[v[0]].paramType.traverse(this) })

        if (!typeManager.isGlobal && scopeType != ScopeType.BODY) {
            typeManager.addFunction(ref)
        }

        if (let Some(decl) <- funcDeclWithRef.declType) {
            referenceStatus.add(ref, Status.VIS)
            ref.effectiveType = decl.traverse(this)
            return typeManager.getType("Unit")
        }

        if (ref.identifier.kind == TokenKind.ILLEGAL) {
            referenceStatus.add(ref, Status.VIS)
            ref.effectiveType = typeManager.getType(currentClass.getOrThrow()
                .classReference.identifier.value)
            return typeManager.getType("Unit")
        }
        
        referenceStatus.add(ref, Status.IN)
        if (funcDeclWithRef.keyword.kind == TokenKind.INIT) {
            inConstructor = true
        }
        
        let infType: Type = funcDeclWithRef.block.traverse(this)

        inConstructor = false
        ref.effectiveType = infType
        referenceStatus.add(ref, Status.VIS)

        typeManager.getType("Unit")
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): Type {
        let ref: MainReference = mainDeclWithRef.mainRef

        // Set effective type to parameter (= to declaration type)
        if (let Some(paramRef) <- ref.paramRef) {
            paramRef.effectiveType = mainDeclWithRef.param.getOrThrow().traverse(this)
        }

        if (let Some(decl) <- mainDeclWithRef.declType) {
            ref.effectiveType = decl.traverse(this)
            return typeManager.getType("Unit")
        }

        let infType: Type = mainDeclWithRef.block.traverse(this)
        ref.effectiveType = infType
        typeManager.getType("Unit")
    }

    public override func visit(varReference: VariableReference): Type {
        varReference.effectiveType.getOrThrow()
    }

    public override func visit(funcReference: FuncReference): Type {
        callableField = funcReference.identifier.value
        funcReference.effectiveType.getOrThrow()
    }

    public override func visit(classReference: ClassReference): Type {
        // Class reference can be called, it will call the init function that has no name.
        callableField = ""
        classReference.effectiveType.getOrThrow()
    }

    public override func visit(refExprWithRef: RefExprWithRef): Type {
        refExprWithRef.ref.traverse(this)
    }

    public override func visit(callExprWithRef: CallExprWithRef): Type {
        let calleeType: Type = callExprWithRef.callee.traverse(this)
        let identifier = callableField.getOrThrow({ =>
            Exception("Left of call expression not callable") })
        let params = callExprWithRef.arguments.iterator().fold<ArrayList<Type>>(ArrayList(),
                    { res, v => res.add(v.traverse(this)); res }).toArray()

        var ref: FuncReference
        // Check first for a function call.
        try {
            ref = typeManager.applyFunction(identifier, params, expectedReturnType.peek())
        } catch(e: Exception) {
            if (let Some(classRef) <- classEnvironment.getGlobal(calleeType.name)) {
                ref = classRef.typeManager.getOrThrow()
                    .applyFunction(identifier, params, expectedReturnType.peek())
            } else {
                throw e
            }
        }

        // TODO: Change this with lambdas.
        callableField = None

        if (let Some(t) <- ref.effectiveType) {
            return t
        }
        if (let Some(status) <- referenceStatus.get(ref) && status == Status.IN) {
            throw Exception("Could not infer the type of ${ref.identifier.value}")
        }
        referenceStatus.add(ref, Status.IN)
        let block: Block = ref.block.getOrThrow({ => Exception("Block not defined for function") })
        let tp: Type = block.traverse(this)
        ref.effectiveType = tp
        referenceStatus.add(ref, Status.VIS)
        return tp
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): Type {
        currentClass = classEnvironment.getGlobal(classDeclWithRef.identifier.value)
        // TODO: Update this when we'll have interfaces.
        // If no supertypes the supertype will be Object.
        if (classDeclWithRef.superTypes.isEmpty()) {
            currentClass.getOrThrow().classReference.parent =
                classEnvironment.getGlobal("Object").getOrThrow().classReference
        } else if (
            classDeclWithRef.superTypes.size == 1 &&
            let Some(superClass) <- classDeclWithRef.superTypes.get(0)
        ) {
            // Update the parent in the reference.
            currentClass.getOrThrow().classReference.parent =
                classEnvironment.getGlobal(superClass.typeName.value).getOrThrow().classReference
        } else {
            throw Exception("Invalid number of superclasses, it can be max 1.")
        }
        classDeclWithRef.ref.effectiveType = typeManager.getType(classDeclWithRef.identifier.value)

        classDeclWithRef.body.traverse(this)
        currentClass = None
        typeManager.getType("Unit")
    }

    public override func visit(body: Body): Type {
        typeManager.beginScope()
        scopeType = ScopeType.BODY

        let variableEnvironment: Environment<String, VariableReference> = Environment()
        let bodyDeclarator: Declarator =
            DeclaratorFactory.bodyAsgDeclarator(variableEnvironment, typeManager)
        body.decls.iterator().forEach({ decl => decl.traverse(bodyDeclarator) })

        currentClass.getOrThrow().typeManager = TypeManager(typeManager)
        currentClass.getOrThrow().variableEnvironment = variableEnvironment

        body.decls.iterator().forEach({ decl => decl.traverse(this) })

        typeManager.endScope()
        scopeType = ScopeType.NIL

        currentClass.getOrThrow().typeManager.getOrThrow().deleteHistory()
        currentClass.getOrThrow().variableEnvironment.getOrThrow().enclosing = None

        DUMMY_TYPE
    }

    public override func visit(memberAccess: MemberAccess): Type {
        // TODO: Remember to change this when we add other class-like structures.
        var baseClass: ClassReferenceForTC =
            classEnvironment.getGlobal((memberAccess.baseExpr.traverse(this).name))
                .getOrThrow({ => Exception("Base of member access is not a class!") })
        let field: String = memberAccess.field.value
        while (let Some(parent) <- baseClass.classReference.parent) {
            if (let Some((tp, isCallable)) <- baseClass.getMember(field)) {
                if (isCallable) {
                    callableField = field
                }
                return tp
            }
            baseClass = classEnvironment.getGlobal(parent.identifier.value).getOrThrow({ =>
                Exception("Parent class is not declared!")})
        }
        if (let Some((tp, isCallable)) <- baseClass.getMember(field)) {
            if (isCallable) {
                callableField = field
            }
            return tp
        }
        DUMMY_TYPE
    }

    public override func visit(thisSuperReference: ThisSuperReference): Type {
        if (inConstructor) {
            callableField = ""
        }

        thisSuperReference.classReference = currentClass.getOrThrow().classReference
        currentClass.getOrThrow().classReference.effectiveType.getOrThrow()
    }
}
