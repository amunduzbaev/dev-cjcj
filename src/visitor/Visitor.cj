package cjcj.visitor

public abstract class Visitor<R> {

    protected open func visit(_: Program): R  {
        throw Exception("Unimplemented method for Visitor : Program")
    }
 
    protected open func visit(_: BinaryExpr): R{
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: UnaryExpr): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: ParenExpr): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: LitConstExpr): R{
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: AssignExpr): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: RefExpr): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: Block): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: IfExpr): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: WhileExpr): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: CallExpr): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: ReturnExpr): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: VarDecl): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: FuncParam): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: FuncDecl): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: MainDecl): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: Argument): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: TypeNode): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: PrimitiveType): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: RefType): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: VariableReference): R {
        throw Exception("Unimplemented method for Visitor : Program")
    }

    protected open func visit(_: FuncReference): R{
        throw Exception("Unimplemented method for Visitor : Program")
    }
}
