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
* It will check that all the operation types and assignments are correct based on the types of the
* elements and based on the defined operations.
*/
public class TypeAssigner <: Visitor<Type> {
    // Dummy type to return when I don't need to return an actual one.
    private static let DUMMY_TYPE = Type("")
    private let expectedReturnType: ArrayStack<Type> = ArrayStack()
    private var variableEnvironment: Environment<String, VariableReference> = Environment()
    private let referenceStatus: Map<Reference, Status> = HashMap()

    private var callableField: ?String = None
    private var currentClass: ?ClassReferenceForTC = None
    private var scopeType: ScopeType = ScopeType.NIL

    public TypeAssigner(
        program: Program, private var classEnvironment: Environment<String, ClassReferenceForTC>,
        private let typeManager: TypeManager
    ) {
        program.traverse(this)
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
            case TokenKind.INTEGER_LITERAL => return typeManager.get("Int64")
            case TokenKind.FLOAT_LITERAL => return typeManager.get("Float64")
            case TokenKind.BOOL_LITERAL => return typeManager.get("Bool")
            case TokenKind.STRING_LITERAL => return typeManager.get("String")
            case TokenKind.UNIT_LITERAL => return typeManager.get("Unit")
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

        typeManager.get("Unit")
    }

    public override func visit(block: Block): Type {
        typeManager.beginScope()
        variableEnvironment = Environment(variableEnvironment)

        let lastId = block.nodes.last.getOrDefault({ => Expr() }).id
        let returnType = block.nodes.iterator()
            .map({ n => (n, n.traverse(this)) })
            .filter({ n => n[0] is ReturnExpr || n[0].id == lastId })
            .map({ n => n[1] })
            .reduce({ a,b => typeManager.smallestCommonSupertype(a, b) })
            .getOrDefault({ => typeManager.get("Unit")})

        typeManager.endScope()
        variableEnvironment = variableEnvironment.enclosing.getOrThrow()
        returnType
    }

    /*
    * Here we want to find the lowest common supertype of all the branches, if an ifExpr doesn't
    * have an else branch then the return type is Unit.
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
        typeManager.get("Unit")
    }

    public override func visit(returnExpr: ReturnExpr): Type {
        if (let Some(expr) <- returnExpr.expr) {
            return expr.traverse(this)
        }
        typeManager.get("Unit")
    }

    public override func visit(funcParam: FuncParam): Type {
        funcParam.paramType.traverse(this)
    }

    public override func visit(argument: Argument): Type {
        argument.expr.traverse(this)
    }

    public override func visit(primitiveType: PrimitiveType): Type {
        typeManager.get(primitiveType.typeName.value)
    }

    public override func visit(refType: RefType): Type {
        typeManager.get(refType.typeName.value)
    }

    public override func visit(varDeclWithRef: VarDeclWithRef): Type {
        let ref: Reference = varDeclWithRef.ref
        if (let Some(status) <- referenceStatus.get(ref) && status == Status.IN) {
            throw Exception("Could not infer the type of ${ref.identifier.value}")
        }

        if (let Some(t) <- varDeclWithRef.declType) {
            referenceStatus.add(ref, Status.VIS)
            ref.effectiveType = t.traverse(this)
            return typeManager.get("Unit")
        }

        referenceStatus.add(ref, Status.IN)
        let initzer: Expr = varDeclWithRef.initializer.getOrThrow({ =>
            Exception("No initializer and no declType in typeChecking, should've been checked" +
                " before") })
        
        let initType: Type = initzer.traverse(this)
        ref.effectiveType = initType
        referenceStatus.add(ref, Status.VIS)
        typeManager.get("Unit")
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
            return typeManager.get("Unit")
        }

        if (ref.identifier.kind == TokenKind.ILLEGAL) {
            referenceStatus.add(ref, Status.VIS)
            ref.effectiveType = typeManager.get(currentClass.getOrThrow()
                .classReference.identifier.value)
            return typeManager.get("Unit")
        }
        
        referenceStatus.add(ref, Status.IN)
        let infType: Type = funcDeclWithRef.block.traverse(this)
        ref.effectiveType = infType
        referenceStatus.add(ref, Status.VIS)
        typeManager.get("Unit")
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): Type {
        let ref: MainReference = mainDeclWithRef.mainRef
        if (let Some(decl) <- mainDeclWithRef.declType) {
            ref.effectiveType = decl.traverse(this)
            return typeManager.get("Unit")
        }
        // Set effective type to parameter (= to declaration type)
        if (let Some(paramRef) <- ref.paramRef) {
            paramRef.effectiveType = mainDeclWithRef.param.getOrThrow().traverse(this)
        }
        let infType: Type = mainDeclWithRef.block.traverse(this)
        ref.effectiveType = infType
        typeManager.get("Unit")
    }

    public override func visit(varReference: VariableReference): Type {
        varReference.effectiveType.getOrThrow()
    }

    public override func visit(funcReference: FuncReference): Type {
        callableField = funcReference.identifier.value
        funcReference.effectiveType.getOrThrow()
    }

    public override func visit(classReference: ClassReference): Type {
        callableField = ""
        classReference.effectiveType.getOrThrow()
    }

    public override func visit(refExprWithRef: RefExprWithRef): Type {
        let tp: Type = refExprWithRef.ref.traverse(this)
        tp
    }

    public override func visit(callExpr: CallExpr): Type {
        let calleeType: Type = callExpr.callee.traverse(this)
        let identifier = callableField.getOrThrow({ =>
            Exception("Left of call expression not callable") })
        let params = callExpr.arguments.iterator().fold<ArrayList<Type>>(ArrayList(),
                    { res, v => res.add(v.traverse(this)); res }).toArray()

        let ref: FuncReference
        if (let Some(classRef) <- classEnvironment.getGlobal(calleeType.name)) {
            ref = classRef.typeManager.getOrThrow()
                .applyFunction(identifier, params, expectedReturnType.peek())
        } else {
            ref = typeManager.applyFunction(identifier, params, expectedReturnType.peek())
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

        classDeclWithRef.body.traverse(this)
        classDeclWithRef.ref.effectiveType = typeManager.get(classDeclWithRef.identifier.value)
        currentClass = None
        typeManager.get("Unit")
    }

    public override func visit(body: Body): Type {
        beginScope()
        scopeType = ScopeType.BODY

        let bodyDeclarator: Declarator =
            DeclaratorFactory.bodyAsgDeclarator(variableEnvironment, typeManager)
        body.decls.iterator().forEach({ decl => decl.traverse(bodyDeclarator) })
        body.decls.iterator().forEach({ decl => decl.traverse(this) })

        currentClass.getOrThrow().typeManager = TypeManager(typeManager)
        currentClass.getOrThrow().variableEnvironment = variableEnvironment

        endScope()
        scopeType = ScopeType.NIL

        currentClass.getOrThrow().typeManager.getOrThrow().deleteHistory()
        currentClass.getOrThrow().variableEnvironment.getOrThrow().enclosing = None

        DUMMY_TYPE
    }

    public override func visit(memberAccess: MemberAccess): Type {
        // TODO: Remember to change this when we add other class-like structures.
        let baseClass: ClassReferenceForTC =
            classEnvironment.getGlobal((memberAccess.baseExpr.traverse(this).name))
                .getOrThrow({ => Exception("Base of member access is not a class!") })
        let field: String = memberAccess.field.value
        var tmpBaseClassVariableEnv: Environment<String, VariableReference> =
            baseClass.variableEnvironment.getOrThrow()

        if (let Some(varRef) <- tmpBaseClassVariableEnv.getLocal(field)) {
            callableField = None
            return varRef.effectiveType.getOrThrow()
        }
        callableField = field    
        typeManager.get(baseClass.classReference.identifier.value)
    }

    private func beginScope(): Unit {
        typeManager.beginScope()
        variableEnvironment = Environment(variableEnvironment)
    }

    private func endScope(): Unit {
        typeManager.endScope()
        variableEnvironment = variableEnvironment.enclosing.getOrThrow()
    }
}