package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.TokenKind

import std.collection.Map
import std.collection.ArrayList
import std.collection.HashMap

/*
* It will check that all the operation types and assignments are correct based on the types of the
* elements and based on the defined operations.
*/
public class TypeChecker <: Visitor<Type> {
    // Dummy type to return when I don't need to return an actual one.
    private static let DUMMY_TYPE = Type("")
    private let typeManager: TypeManager

    public init(program: Program) {
        typeManager = TypeDeclarationChecker().resolve(program)
        program.traverse(this)
    }

    public override func visit(program: Program): Type {
        let environmentTime = typeManager.record()

        program.decls.iterator().forEach({ d => d.traverse(this) })

        typeManager.rollBack(environmentTime)
        DUMMY_TYPE
    }

    public override func visit(binaryExpr: BinaryExpr): Type {
        let left: Type = binaryExpr.left.traverse(this)
        let right: Type = binaryExpr.right.traverse(this)
        typeManager.applyFunction(binaryExpr.oper.value, left, right)
    }

    public override func visit(unaryExpr: UnaryExpr): Type {
        let right: Type = unaryExpr.right.traverse(this)
        typeManager.applyFunction(unaryExpr.oper.value, right)
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
        let right: Type = assignExpr.right.traverse(this)
        if (!left.isParent(right)) {
            throw Exception("Cannot assign ${right.name} to ${left.name}")
        }
        Type("Unit")
    }

    public override func visit(block: Block): Type {
        let environmentTime = typeManager.record()

        // TODO: This is very wrong, We should do the check with all the returns.
        let returnType = block.nodes.iterator()
            .map({ n =>
                n.traverse(this)
            })
            .reduce({ a,b => typeManager.smallestCommonSupertype(a, b) })
            .getOrDefault({ => Type("Unit")})

        typeManager.rollBack(environmentTime)
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
        Type("Unit")
    }

    public override func visit(returnExpr: ReturnExpr): Type {
        if (let Some(expr) <- returnExpr.expr) {
            return expr.traverse(this)
        }
        Type("Unit")
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
        if (let Some(initzer) <- varDeclWithRef.initializer) {
            let initType: Type = initzer.traverse(this)
            if (let Some(t) <- varDeclWithRef.declType) {
                let dType: Type = t.traverse(this)
                if (!dType.isParent(initType)) {
                    throw Exception("Assigned type not correct, expected ${dType.name} " +
                        "found ${initType.name}")
                }
                ref.effectiveType = dType
            } else {
                ref.effectiveType = initType
            }
        } else {
            ref.effectiveType = varDeclWithRef.declType.getOrThrow({ =>
                Exception("No initializer and no declType in typeChecking, should've been checked" +
                    " before") }).traverse(this)
        }
        typeManager.get("Unit")
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): Type {
        let ref: FuncReference = funcDeclWithRef.funcRef
        var returnType: ?Type = None
        if (let Some(decl) <- funcDeclWithRef.declType) {
            returnType = decl.traverse(this)
        }

        // Set effective type to parameters (= to declaration type)
        funcDeclWithRef.paramRef.iterator()
            .forEach({ p => p.effectiveType = p.declType.getOrThrow().traverse(this) })
        
        let infType: Type = funcDeclWithRef.block.traverse(this)
        if (let Some(retType) <- returnType) {
            if (!retType.isParent(infType)) {
                throw Exception("Type of function not correct, defined ${retType.name}, found: " +
                    "${infType.name}")
            }
            ref.effectiveType = retType
        } else {
            ref.effectiveType = infType
        }
        
        typeManager.addFunction(ref.identifier.value, ref.params.iterator()
            .fold<ArrayList<Type>>(ArrayList(),
                { res, v => res.add(v.traverse(this)); res}).toArray(),
            ref.effectiveType.getOrThrow()
        )
        typeManager.get("Unit")
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): Type {
        var returnType: ?Type = None
        if (let Some(decl) <- mainDeclWithRef.declType) {
            returnType = decl.traverse(this)
        }
        if (let Some(param) <- mainDeclWithRef.paramRef) {
            param.effectiveType = param.declType.getOrThrow().traverse(this)
        }
        let infType: Type = mainDeclWithRef.block.traverse(this)
        if (let Some(retType) <- returnType) {
            if (!retType.isParent(infType)) {
                throw Exception("Type of function not correct, defined ${retType.name}, found: " +
                    "${infType.name}")
            }
        }
        typeManager.get("Unit")
    }

    public override func visit(varReference: VariableReference): Type {
        varReference.effectiveType.getOrThrow()
    }

    public override func visit(_: FuncReference): Type{
        // This will return the lambda type in the future.
        throw Exception("Unimplemented method for Visitor : Function Reference (ASG)")
    }

    public override func visit(callExpr: CallExpr): Type {
        let ref = (callExpr.callee as FuncReference).getOrThrow()

        typeManager.applyFunction(
            ref.identifier.value,
            callExpr.arguments.iterator().fold<ArrayList<Type>>(ArrayList(),
                { res, v => res.add(v.traverse(this)); res }).toArray()
        )
    }

    public override func visit(classDecl: ClassDecl): Type {
        classDecl.body.traverse(this)
        typeManager.get("Unit")
    }

    public override func visit(_: Body): Type {
        // body.decls.iterator().forEach({ decl => decl.traverse(this) })
        typeManager.get("Unit")
    }
}