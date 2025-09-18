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
    private let typeAssigner: TypeAssigner
    private let typeManager: TypeManager
    private let expectedReturnType: ArrayStack<Type> = ArrayStack()
    private var variableEnvironment: Environment<String, VariableReference> = Environment()
    private var classEnvironment: Environment<String, ClassReferenceForTC> = Environment()
    private var callableField: ?String = None
    private var currentClassRef: ?ClassReferenceForTC = None
    private var inConstructor: Bool = false

    public init(program: Program) {
        typeManager = TypeDeclarationChecker().resolve(program)
        typeAssigner = TypeAssigner(classEnvironment, typeManager)

        let tmpClassEnvironment: Environment<String, ClassReference> = Environment()
        declareBuiltinClassReferences(tmpClassEnvironment)

        let globalTypeDeclarator: Declarator = DeclaratorFactory.globalAsgDeclarator(
            tmpClassEnvironment, typeManager
        )
        program.decls.iterator().forEach({ d => d.traverse(globalTypeDeclarator) })
        tmpClassEnvironment.elements.iterator()
            .forEach({ cr => classEnvironment.declare(cr[0], ClassReferenceForTC(cr[1])) })

        program.traverse(typeAssigner)
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

        block.nodes.iterator().forEach({ n => n.traverse(typeAssigner) })

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
        if (inConstructor) {
            throw Exception("Cannot have a return inside a constructor")
        }
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
        
        if (ref.identifier.kind != TokenKind.ILLEGAL) {
            let prevInConstructor: Bool = inConstructor
            inConstructor = false
            typeAssigner.inConstructor = prevInConstructor

            let infType: Type = funcDeclWithRef.block.traverse(this)
            if (!assignedType.isParent(infType)) {
                throw Exception("Type of function not correct, expected ${assignedType.name}, " +
                    "found: ${infType.name}")
            }

            inConstructor = prevInConstructor
            typeAssigner.inConstructor = prevInConstructor
        } else {
            inConstructor = true
            typeAssigner.inConstructor = true
            funcDeclWithRef.block.traverse(this)
            inConstructor = false
            typeAssigner.inConstructor = false
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

        // TODO: Change this with lambdas.
        callableField = None

        callExprWithRef.ref = ref
        ref.effectiveType.getOrThrow()
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): Type {
        let classRefForTC = classEnvironment.getGlobal(classDeclWithRef.ref.identifier.value)
            .getOrThrow({ => Exception("Unexpected, class should've been declared")})
        checkBodyDecl(classRefForTC)
        currentClassRef = classRefForTC

        classDeclWithRef.body.traverse(this)

        currentClassRef = None
        typeManager.getType("Unit")
    }

    public override func visit(body: Body): Type {
        body.decls.iterator().forEach({ decl => decl.traverse(this) })
        Type.DUMMY
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
        Type.DUMMY
    }

    private func beginScope(): Unit {
        typeManager.beginScope()
        variableEnvironment = Environment(variableEnvironment)
    }

    private func endScope(): Unit {
        typeManager.endScope()
        variableEnvironment = variableEnvironment.enclosing.getOrThrow()
    }

    /*
    * Checks that there is no shadowing of the super members.
    */
    private func checkBodyDecl(classReferenceTC: ClassReferenceForTC): Unit {
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