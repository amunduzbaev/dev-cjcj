package cjcj.ast

public abstract class Visitor {
    private var breakTraverseFlag = false

    protected func needBreakTraverse(): Bool {
        if (breakTraverseFlag) {
            breakTraverseFlag = false
            return true
        }
        return false
    }

    public func breakTraverse(): Unit {
        breakTraverseFlag = true
    }

    protected open func visit(_: Program): Unit { }

    protected open func visit(_: Expr): Unit { }

    protected open func visit(_: BinaryExpr): Unit { }

    protected open func visit(_: UnaryExpr): Unit { }

    protected open func visit(_: ParenExpr): Unit { }

    protected open func visit(_: LitConstExpr): Unit { }

    protected open func visit(_: AssignExpr): Unit { }

    protected open func visit(_: RefExpr): Unit { }

    protected open func visit(_: Block): Unit { }

    protected open func visit(_: IfExpr): Unit { }

    protected open func visit(_: WhileExpr): Unit { }

    protected open func visit(_: CallExpr): Unit { }

    protected open func visit(_: ReturnExpr): Unit { }

    protected open func visit(_: Decl): Unit { }

    protected open func visit(_: VarDecl): Unit { }

    protected open func visit(_: FuncParam): Unit { }

    protected open func visit(_: FuncDecl): Unit { }

    protected open func visit(_: Argument): Unit { }

    protected open func visit(_: TypeNode): Unit { }

    protected open func visit(_: PrimitiveType): Unit { }

    protected open func visit(_: RefType): Unit { }
}