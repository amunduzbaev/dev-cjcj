package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.asg.ScopeType
import cjcj.asg.TypeManager
import cjcj.asg.Declarator
import cjcj.asg.DeclaratorFactory

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
    private var variableEnvironment: Environment<String, VariableReference> = Environment()
    private var classEnvironment: Environment<String, ClassReferenceForTC> = Environment()
    private var callableField: ?String = None

    public init(program: Program) {
        typeManager = TypeDeclarationChecker().resolve(program)
        let tmpClassEnvironment: Environment<String, ClassReference> = Environment()
        let globalTypeDeclarator: Declarator = DeclaratorFactory.globalAsgDeclarator(
            tmpClassEnvironment, typeManager
        )
        program.decls.iterator().forEach({ d => d.traverse(globalTypeDeclarator) })
        tmpClassEnvironment.elements.iterator()
            .forEach({ cr => classEnvironment.declare(cr[0], ClassReferenceForTC(cr[1])) })
        TypeAssigner(program, classEnvironment, typeManager)
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
        let assignedType: Type = ref.effectiveType
            .getOrThrow({ => Exception("Type not yet assigned!")})
        if (let Some(initzer) <- varDeclWithRef.initializer) {
            let initType: Type = initzer.traverse(this)
            if (!assignedType.isParent(initType)) {
                throw Exception("Assigned type not correct, expected ${assignedType.name} " +
                    "found ${initType.name}")
            }
        }
        typeManager.getType("Unit")
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): Type {
        let ref: FuncReference = funcDeclWithRef.funcRef
        let assignedType: Type = ref.effectiveType
            .getOrThrow({ => Exception("Type not yet assigned!")})
        
        // TODO: INIT CANNOT HAVE RETURN INSIDE I GUESS, RIGHT NOW I'M NOT CHECKING IT.
        if (ref.identifier.kind != TokenKind.ILLEGAL) {
            let infType: Type = funcDeclWithRef.block.traverse(this)
            if (!assignedType.isParent(infType)) {
                throw Exception("Type of function not correct, expected ${assignedType.name}, " +
                    "found: ${infType.name}")
            }
        }
        if (!typeManager.isGlobal) {
            typeManager.addFunction(ref)
        }
        typeManager.getType("Unit")
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
        callableField = funcReference.identifier.value
        funcReference.effectiveType.getOrThrow()
    }

    public override func visit(refExprWithRef: RefExprWithRef): Type {
        let tp: Type = refExprWithRef.ref.traverse(this)
        tp
    }

    public override func visit(callExpr: CallExpr): Type {
        let tp: Type = callExpr.callee.traverse(this)
        let identifier = callableField.getOrThrow({ =>
            Exception("Left of call expression not callable") })
        let params = callExpr.arguments.iterator().fold<ArrayList<Type>>(ArrayList(),
                    { res, v => res.add(v.traverse(this)); res }).toArray()

        let ref: FuncReference
        if (let Some(classRef) <- classEnvironment.getGlobal(tp.name)) {
            ref = classRef.typeManager.getOrThrow()
                .applyFunction(identifier, params, expectedReturnType.peek())
        } else {
            ref = typeManager.applyFunction(identifier, params, expectedReturnType.peek())
        }

        // TODO: Change this with lambdas.
        callableField = None

        callExpr.callee = ref
        ref.effectiveType.getOrThrow()
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): Type {
        classDeclWithRef.body.traverse(this)
        typeManager.getType("Unit")
    }

    public override func visit(body: Body): Type {
        body.decls.iterator().forEach({ decl => decl.traverse(this) })
        DUMMY_TYPE
    }

    public override func visit(memberAccess: MemberAccess): Type {
        // TODO: Remember to change this when we add other class-like structures.
        var baseClass: ClassReferenceForTC =
            classEnvironment.getGlobal((memberAccess.baseExpr.traverse(this).name))
                .getOrThrow({ => Exception("Base of member access is not a class!") })
        let field: String = memberAccess.field.value
        while (let Some(parent) <- baseClass.classReference.parent) {
            if (let Some(tp) <- getClassMember(baseClass, field)) {
                return tp
            }
            baseClass = classEnvironment.getGlobal(parent.identifier.value).getOrThrow({ =>
                Exception("Parent class is not declared!")})
        }
        if (let Some(tp) <- getClassMember(baseClass, field)) {
            return tp
        }
        DUMMY_TYPE
    }

    private func getClassMember(baseClass: ClassReferenceForTC, field: String): ?Type {
        let baseClassVariableEnv: Environment<String, VariableReference> =
            baseClass.variableEnvironment.getOrThrow()
        let baseClassTypeManager: TypeManager = baseClass.typeManager.getOrThrow()

        // Try to find a variable.
        if (let Some(varRef) <- baseClassVariableEnv.getLocal(field)) {
            callableField = None
            println("Found ${field}")
            return varRef.effectiveType.getOrThrow()
        }

        // Try to find a function.
        if (baseClassTypeManager.funcExists(field)) {
            callableField = field
            // I cannot know the return type of the function so I just tell the callExpr who to call
            // and from which class.
            return typeManager.getType(baseClass.classReference.identifier.value)
        }
        None
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