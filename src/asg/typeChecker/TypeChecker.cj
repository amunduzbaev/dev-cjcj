package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.asg.declarator.*

import std.collection.*

/*
* It will check that all the operation types and assignments are correct based on the types of the
* elements and based on the defined operations.
*/
public class TypeChecker <: Visitor<Type> {
    // Dummy type to return when I don't need to return an actual one.
    private static let DUMMY_TYPE = Type("")
    private let typeManager: TypeManager
    private let expectedReturnType: ArrayStack<Type> = ArrayStack()
    private var funcEnvironment: Environment<String, FuncReference> = Environment()
    private var variableEnvironment: Environment<String, VariableReference> = Environment()

    public init(program: Program) {
        typeManager = TypeDeclarationChecker().resolve(program)
        let functionDeclarator: Declarator = DeclaratorFactory.functionTypeDeclarator(
            funcEnvironment, typeManager)
        program.decls.iterator().forEach({ d => d.traverse(functionDeclarator) })
        // funcEnvironment.elements.values().iterator().forEach({ funcRef => typeManager.addFunction(funcRef) })
        TypeAssigner(program, funcEnvironment, typeManager)
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
        funcEnvironment = Environment(funcEnvironment)
        variableEnvironment = Environment(variableEnvironment)

        let lastId = block.nodes.last.getOrDefault({ => Expr() }).id
        let returnType = block.nodes.iterator()
            .map({ n => (n, n.traverse(this)) })
            .filter({ n => n[0] is ReturnExpr || n[0].id == lastId })
            .map({ n => n[1] })
            .reduce({ a,b => typeManager.smallestCommonSupertype(a, b) })
            .getOrDefault({ => typeManager.get("Unit")})

        typeManager.endScope()
        funcEnvironment = funcEnvironment.enclosing.getOrThrow()
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
        let assignedType: Type = ref.effectiveType
            .getOrThrow({ => Exception("Type not yet assigned!")})
        if (let Some(initzer) <- varDeclWithRef.initializer) {
            let initType: Type = initzer.traverse(this)
            if (!assignedType.isParent(initType)) {
                throw Exception("Assigned type not correct, expected ${assignedType.name} " +
                    "found ${initType.name}")
            }
        }
        typeManager.get("Unit")
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): Type {
        let ref: FuncReference = funcDeclWithRef.funcRef
        let assignedType: Type = ref.effectiveType
            .getOrThrow({ => Exception("Type not yet assigned!")})
        
        let infType: Type = funcDeclWithRef.block.traverse(this)
        if (!assignedType.isParent(infType)) {
            throw Exception("Type of function not correct, expected ${assignedType.name}, found: " +
                "${infType.name}")
        }
        if (!funcEnvironment.isGlobal) {
            typeManager.addFunction(ref)
        }
        typeManager.get("Unit")
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): Type {
        let ref: MainReference = mainDeclWithRef.mainRef
        let assignedType: Type = ref.effectiveType
            .getOrThrow({ => Exception("Type not yet assigned!")})

        let infType: Type = mainDeclWithRef.block.traverse(this)
        if (!assignedType.isParent(infType)) {
            throw Exception("Type of function not correct, expected ${assignedType.name}, found: " +
                "${infType.name}")
        }
        typeManager.get("Unit")
    }

    public override func visit(varReference: VariableReference): Type {
        varReference.effectiveType.getOrThrow()
    }

    public override func visit(funcReference: FuncReference): Type{
        funcReference.effectiveType.getOrThrow()
    }

    public override func visit(refExprWithRef: RefExprWithRef): Type {
        refExprWithRef.ref.traverse(this)
    }

    public override func visit(callExpr: CallExpr): Type {
        var ref: FuncReference = (callExpr.callee as FuncReference).getOrThrow()

        ref = typeManager.applyFunction(
            ref.identifier.value,
            callExpr.arguments.iterator().fold<ArrayList<Type>>(ArrayList(),
                { res, v => res.add(v.traverse(this)); res }).toArray(),
            expectedReturnType.peek()
        )
        callExpr.callee = ref
        ref.effectiveType.getOrThrow()
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): Type {
        classDeclWithRef.body.traverse(this)
        typeManager.get("Unit")
    }

    public override func visit(_: Body): Type {
        // body.decls.iterator().forEach({ decl => decl.traverse(this) })
        typeManager.get("Unit")
    }
}