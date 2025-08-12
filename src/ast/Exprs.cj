package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.collection.ArrayList

public open class Expr <: Node {
    public init(id: NodeId) {
        super(id)
    }

    public override open func prettyPrint(_: PrettyPrinter): Unit { }
}

public class Binary <: Expr {
    private let left_: Expr
    private let oper_: Token
    private let right_: Expr

    public Binary(id: NodeId, left: Expr, oper: Token, right: Expr) {
        super(id)
        left_ = left
        oper_ = oper
        right_ = right
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

public class Grouping <: Expr {
    private let node_: Expr

    public Grouping(id: NodeId, node: Expr) {
        super(id)
        node_ = node
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append("(")
        node.prettyPrint(printer)
        printer.append(")")
    }

    public prop node: Expr {
        get() { node_ }
    }
}

public class Literal <: Expr {
    private let value_: ToString

    public Literal(id: NodeId, value: ToString) {
        super(id)
        value_ = value
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append(value.toString())
    }

    public prop value: ToString {
        get() { value_ }
    }
}

public class Unary <: Expr {
    private let oper_: Token
    private let right_: Expr

    public Unary(id: NodeId, oper: Token, right: Expr) {
        super(id)
        oper_ = oper
        right_ = right
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

public class Assign <: Expr {
    private let left_: Expr
    private let right_: Expr

    public Assign(id: NodeId, name: Expr, value: Expr) {
        super(id)
        left_ = name
        right_ = value
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

    public prop identifier: Token {
        get() { identifier_ }
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append(identifier.value)
    }
}

public class ThisSuperExpr <: Expr {
    private var identifier_: Token

    public ThisSuperExpr(id: NodeId, identifier: Token) {
        super(id)
        identifier_ = identifier
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

public class Body <: Expr {
    private let decls_: Array<Decl>

    public Body(id: NodeId, decls: Array<Decl>) {

        super(id)
        decls_ = decls
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        
        printer.append("{")
        if (!decls.isEmpty()) {
            printer.indent()
            printer.append("\n")
            decls[0].prettyPrint(printer)
            decls.iterator()
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

    public prop decls: Array<Decl> {
        get() { decls_ }
    }
}

public class IfExpr <: Expr {
    private let condition_: Expr
    private let ifBlock_: Block
    private let elseBranch_: ?Expr

    public init(id: NodeId, condition: Expr, ifBlock: Block) {
        this(id, condition, ifBlock, None)
    }

    public IfExpr(id: NodeId, condition: Expr, ifBlock: Block, elseBranch: ?Expr) {
        super(id)
        condition_ = condition
        ifBlock_ = ifBlock
        elseBranch_ = elseBranch
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
    private let value_: Expr 
    private let keyword_: Token

    public ReturnExpr(id: NodeId, value: Expr, keyword: Token) {
        super(id)
        value_ = value
        keyword_ = keyword
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append(keyword.value + " ")
        value.prettyPrint(printer)
    }

    public prop value: Expr {
        get() { value_ }
    }

    public prop keyword: Token {
        get() { keyword_ }
    }
}

public class MemberAccess <: Expr {
    private let baseExpr_: Expr
    private let field_: Token

    public MemberAccess(id: NodeId, baseExpr: Expr, field: Token) {
        super(id)
        baseExpr_ = baseExpr
        field_ = field
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        baseExpr.prettyPrint(printer)
        printer.append("." + field.value)
    }

    public prop baseExpr: Expr {
        get() { baseExpr_ }
    }

    public prop field: Token {
        get() { field_ }
    }

}
