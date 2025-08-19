package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.collection.ArrayList

public open class Expr <: Node {
    public init(id: NodeId) {
        super(id)
    }

    public override open func traverse(v: Visitor): Unit {
        v.visit(this)
    }

    public override open func prettyPrint(_: PrettyPrinter): Unit { }
}

public class BinaryExpr <: Expr {
    private let left_: Expr
    private let oper_: Token
    private let right_: Expr

    public BinaryExpr(id: NodeId, left: Expr, oper: Token, right: Expr) {
        super(id)
        left_ = left
        oper_ = oper
        right_ = right
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (!v.needBreakTraverse()) { return }
        left.traverse(v)
        right.traverse(v)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        left.prettyPrint(printer)
        printer.append(" ${oper.value} ")
        right.prettyPrint(printer)
    }

    public prop left: Expr {
        get() { left_ }
    }

    public prop oper: Token {
        get() { oper_ }
    }

    public prop right: Expr {
        get() { right_ }
    }
}

public class ParenExpr <: Expr {
    private let parenthesizedExpr_: Expr

    public ParenExpr(id: NodeId, parenthesizedExpr: Expr) {
        super(id)
        parenthesizedExpr_ = parenthesizedExpr
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (!v.needBreakTraverse()) { return }
        expr.traverse(v)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append("(")
        parenthesizedExpr.prettyPrint(printer)
        printer.append(")")
    }

    public prop parenthesizedExpr: Expr {
        get() { parenthesizedExpr_ }
    }
}

public class LitConstExpr <: Expr {
    private let literal_: Token

    public LitConstExpr(id: NodeId, value: Token) {
        super(id)
        literal_ = value
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append(literal.value)
    }

    public prop literal: Token {
        get() { literal_ }
    }
}

public class UnaryExpr <: Expr {
    private let oper_: Token
    private let right_: Expr

    public UnaryExpr(id: NodeId, oper: Token, right: Expr) {
        super(id)
        oper_ = oper
        right_ = right
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (!v.needBreakTraverse()) { return }
        right.traverse(v)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append("${oper.value}")
        right.prettyPrint(printer)
    }

    public prop oper: Token {
        get() { oper_ }
    }

    public prop right: Expr {
        get() { right_ }
    }
}

public class AssignExpr <: Expr {
    private let left_: Expr
    private let right_: Expr

    public AssignExpr(id: NodeId, name: Expr, value: Expr) {
        super(id)
        left_ = name
        right_ = value
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (!v.needBreakTraverse()) { return }
        left.traverse(v)
        right.traverse(v)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        left.prettyPrint(printer)
        printer.append(" = ")
        right.prettyPrint(printer)
    }

    public prop left: Expr {
        get() { left_ }
    }

    public prop right: Expr {
        get() { right_ }
    }
}

public class RefExpr <: Expr {
    private var identifier_: Token

    public RefExpr(id: NodeId, identifier: Token) {
        super(id)
        identifier_ = identifier
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
    }

    public prop identifier: Token {
        get() { identifier_ }
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append(identifier.value)
    }
}

public class Block <: Expr {
    private let nodes_: Array<Node>

    public Block(id: NodeId, statements: Array<Node>) {
        super(id)
        nodes_ = statements
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (!v.needBreakTraverse()) { return }
        nodes.iterator().forEach({ n => n.traverse(v) })
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append("{")
        if (!nodes.isEmpty()) {
            printer.indent()
            printer.append("\n")
            nodes[0].prettyPrint(printer)
            nodes.iterator()
                .enumerate()
                .filter({ v => v[0] > 0})
                .map({ v => v[1] })
                .forEach({ 
                n => printer.append("\n")    
                    n.prettyPrint(printer)     
                })
            printer.unindent()
        }
        printer.append("\n}\n")
    }

    public prop nodes: Array<Node> {
        get() { nodes_ }
    }
}

public class IfExpr <: Expr {
    private let condition_: Expr
    private let ifBlock_: Block
    private let elseBranch_: ?Expr

    public init(id: NodeId, condition: Expr, ifBlock: Block) {
        this(id, condition, ifBlock, None)
    }

    public IfExpr(id: NodeId, condition: Expr, ifBlock: Block,
                    elseBranch: ?Expr) {
        super(id)
        condition_ = condition
        ifBlock_ = ifBlock
        elseBranch_ = elseBranch
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (!v.needBreakTraverse()) { return }
        condition.traverse(v)
        ifBlock.traverse(v)
        if (let Some(branch) <- elseBranch) {
            branch.traverse(v)
        }
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append("if (")
        condition.prettyPrint(printer)
        printer.append(") ")
        ifBlock.prettyPrint(printer)
        if (let Some(eb) <- elseBranch) {
            printer.append("else ")
            eb.prettyPrint(printer)
        }
    }

    public prop condition: Expr {
        get() { condition_ }
    }

    public prop ifBlock: Block {
        get() { ifBlock_ }
    }

    public prop elseBranch: ?Expr {
        get() { elseBranch_ }
    }
}

public class WhileExpr <: Expr {
    private let condition_: Expr
    private let block_: Block

    public WhileExpr(id: NodeId, condition: Expr, block: Block) {
        super(id)
        condition_ = condition
        block_ = block
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (!v.needBreakTraverse()) { return }
        condition.traverse(v)
        block.traverse(v)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append("while (")
        condition.prettyPrint(printer)
        printer.append(") ")
        block.prettyPrint(printer)
    }

    public prop condition: Expr {
        get() { condition_ }
    }

    public prop block: Block {
        get() { block_ }
    }
}

public class CallExpr <: Expr {
    private let callee_: Expr
    private let arguments_: ArrayList<Argument>

    public CallExpr(id: NodeId, callee: Expr, arguments: ArrayList<Argument>) {
        super(id)
        callee_ = callee
        arguments_ = arguments
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (!v.needBreakTraverse()) { return }
        callee.traverse(v)
        arguments.iterator().forEach({ a => a.traverse(v) })
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        callee.prettyPrint(printer)
        printer.append("(")
        if (!arguments.isEmpty()) {
            arguments[0].prettyPrint(printer)
            arguments.iterator()
                .enumerate()
                .filter({ a => a[0] > 0})
                .map({ a => a[1] })
                .forEach({ a => printer.append(", "); a.prettyPrint(printer)})
        }
        printer.append(")")
    }

    public prop callee: Expr {
        get() { callee_ }
    }
    public prop arguments: ArrayList<Argument> {
        get() { arguments_ }
    }
}

public class ReturnExpr <: Expr {
    private let expr_: ?Expr 
    private let keyword_: Token

    public ReturnExpr(id: NodeId, value: ?Expr, keyword: Token) {
        super(id)
        expr_ = value
        keyword_ = keyword
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (!v.needBreakTraverse()) { return }
        value.traverse(v)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append(keyword.value + " ")
        try {
            expr.prettyPrint(printer)
        } catch (_) {
        }
    }

    public prop expr: Expr {
        get() {
            match(expr_) {
                case Some(v) => v
                case None => throw Exception(
                    "Current return expression has none expr")
            }
        }
    }

    public prop keyword: Token {
        get() { keyword_ }
    }
}

public class JumpExpr <: Expr {
    private let keyword_: Token

    public JumpExpr(id: NodeId, keyword: Token) {
        super(id)
        keyword_ = keyword
    }

    public prop keyword: Token {
        get() { keyword_ }
    }
}
