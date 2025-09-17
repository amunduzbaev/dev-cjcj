package cjcj.visitor

public abstract class Visitor<R> {

    protected open func visit(_: Program): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }
 
    protected open func visit(_: BinaryExpr): R {
        throw Exception("Unimplemented method for Visitor : Binary Expression")
    }

    protected open func visit(_: UnaryExpr): R {
        throw Exception("Unimplemented method for Visitor : Unary Expression")
    }

    protected open func visit(_: ParenExpr): R {
        throw Exception("Unimplemented method for Visitor : Parent Expression")
    }

    protected open func visit(_: LitConstExpr): R {
        throw Exception("Unimplemented method for Visitor : Literal Constant Expression")
    }

    protected open func visit(_: AssignExpr): R {
        throw Exception("Unimplemented method for Visitor : Assign Expression")
    }

    protected open func visit(_: RefExpr): R {
        throw Exception("Unimplemented method for Visitor : Reference Expression")
    }

    protected open func visit(_: Block): R {
        throw Exception("Unimplemented method for Visitor : Block Expression")
    }

    protected open func visit(_: IfExpr): R {
        throw Exception("Unimplemented method for Visitor : If Expression")
    }

    protected open func visit(_: WhileExpr): R {
        throw Exception("Unimplemented method for Visitor : While Expression")
    }

    protected open func visit(_: CallExpr): R {
        throw Exception("Unimplemented method for Visitor : Call Expression")
    }

    protected open func visit(_: ReturnExpr): R {
        throw Exception("Unimplemented method for Visitor : Return Expression")
    }

    protected open func visit(_: JumpExpr): R {
        throw Exception("Unimplemented method for Visitor : Jump Expression")
    }

    protected open func visit(_: VarDecl): R {
        throw Exception("Unimplemented method for Visitor : Variable Declaration")
    }

    protected open func visit(_: FuncParam): R {
        throw Exception("Unimplemented method for Visitor : Function Paramters")
    }

    protected open func visit(_: FuncDecl): R {
        throw Exception("Unimplemented method for Visitor : Function Declaration")
    }

    protected open func visit(_: MainDecl): R {
        throw Exception("Unimplemented method for Visitor : Main Declaration")
    }

    protected open func visit(_: ClassDecl): R {
        throw Exception("Unimplemented method for Visitor : Class Declaration")
    }

    protected open func visit(_: Body): R {
        throw Exception("Unimplemented method for Visitor : Body")
    }

    protected open func visit(_: Argument): R {
        throw Exception("Unimplemented method for Visitor : Argument")
    }

    protected open func visit(_: TypeNode): R {
        throw Exception("Unimplemented method for Visitor : Type Node")
    }

    protected open func visit(_: PrimitiveType): R {
        throw Exception("Unimplemented method for Visitor : Primitive Types")
    }

    protected open func visit(_: RefType): R {
        throw Exception("Unimplemented method for Visitor : Reference Type")
    }

    protected open func visit(_: VariableReference): R {
        throw Exception("Unimplemented method for Visitor : Variable Reference (ASG)")
    }

    protected open func visit(_: FuncReference): R {
        throw Exception("Unimplemented method for Visitor : Function Reference (ASG)")
    }

    protected open func visit(_: ClassReference): R {
        throw Exception("Unimplemented method for Visitor : Class Reference (ASG)")
    }

    protected open func visit(_: VarDeclWithRef): R {
        throw Exception("Unimplemented method for Visitor : Variable Declaration with" + 
                        "References Stored (ASG)")
    }

    protected open func visit(_: FuncDeclWithRef): R {
        throw Exception("Unimplemented method for Visitor : Function Declaration with" + 
                        "References Stored (ASG)")
    }

    protected open func visit(_: MainDeclWithRef): R {
        throw Exception("Unimplemented method for Visitor : Main Declaration with" + 
                        "References Stored (ASG)")
    }

    protected open func visit(_: ClassDeclWithRef): R {
        throw Exception("Unimplemented method for Visitor : Class Declaration with" + 
                        "References Stored (ASG)")
    }

    protected open func visit(_: MemberAccess): R {
        throw Exception("Unimplemented method for Visitor : Member Access")
    }

    protected open func visit(_: PrimitiveTypeExpr): R {
        throw Exception("Unimplemented method for Visitor : Primitive type expression")
    }

    protected open func visit(_: RefExprWithRef): R {
        throw Exception("Unimplemented method for Visitor : Reference expression with reference")
    }

    protected open func visit(_: ThisSuperExpr): R {
        throw Exception("Unimplemented method for Visitor : This Super expression")
    }

    protected open func visit(_: ThisSuperReference): R {
        throw Exception("Unimplemented method for Visitor : This Super reference")
    }

    protected open func visit(_: CallExprWithRef): R {
        throw Exception("Unimplemented method for Visitor : Call expression with reference")
    }
}
