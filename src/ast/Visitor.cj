package cjcj.ast

public abstract class Visitor<R> {

    protected open func visit(_: Program): R

    protected open func visit(_: BinaryExpr): R

    protected open func visit(_: UnaryExpr): R

    protected open func visit(_: ParenExpr): R

    protected open func visit(_: LitConstExpr): R

    protected open func visit(_: AssignExpr): R

    protected open func visit(_: RefExpr): R

    protected open func visit(_: Block): R

    protected open func visit(_: IfExpr): R

    protected open func visit(_: WhileExpr): R

    protected open func visit(_: CallExpr): R

    protected open func visit(_: ReturnExpr): R

    protected open func visit(_: VarDecl): R

    protected open func visit(_: FuncParam): R

    protected open func visit(_: FuncDecl): R

    protected open func visit(_: MainDecl): R

    protected open func visit(_: Argument): R

    protected open func visit(_: TypeNode): R

    protected open func visit(_: PrimitiveType): R

    protected open func visit(_: RefType): R
}