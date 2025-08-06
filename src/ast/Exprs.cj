package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.collection.ArrayList

public open class Expr <: Node {
    public init() {
        super()
    }

    public override open func prettyPrint() { }
}

public class Binary <: Expr {
    private let left_: Expr
    private let oper_: Token
    private let right_: Expr

    public Binary(left: Expr, oper: Token, right: Expr) {
        super()
        left_ = left
        oper_ = oper
        right_ = right
    }

    public override func prettyPrint() {
        left.prettyPrint()
        PrettyPrinter.append(" ${oper.value} ")
        right.prettyPrint()
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

public class Logical <: Expr {
    private let left_: Expr
    private let oper_: Token
    private let right_: Expr

    public Logical(left: Expr, oper: Token, right: Expr) {
        super()
        left_ = left
        oper_ = oper
        right_ = right
    }

    public override func prettyPrint() {
        left.prettyPrint()
        PrettyPrinter.append(" ${oper.value} ")
        right.prettyPrint()
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

    public Grouping(node: Expr) {
        super()
        node_ = node
    }

    public override func prettyPrint() {
        PrettyPrinter.append("(")
        node.prettyPrint()
        PrettyPrinter.append(")")
    }

    public prop node: Expr {
        get() { node_ }
    }
}

public class Literal <: Expr {
    private let value_: ToString

    public Literal(value: ToString) {
        super()
        value_ = value
    }

    public override func prettyPrint() {
        PrettyPrinter.append(value.toString())
    }

    public prop value: ToString {
        get() { value_ }
    }
}

public class Unary <: Expr {
    private let oper_: Token
    private let right_: Expr

    public Unary(oper: Token, right: Expr) {
        super()
        oper_ = oper
        right_ = right
    }

    public override func prettyPrint() {
        PrettyPrinter.append("${oper.toString()}")
        right.prettyPrint()
    }

    public prop oper: Token {
        get() { oper_ }
    }

    public prop right: Expr {
        get() { right_ }
    }
}

public class Assign <: Expr {
    private let name_: Token
    private let value_: Expr

    public Assign(name: Token, value: Expr) {
        super()
        name_ = name
        value_ = value
    }

    public override func prettyPrint() {
        PrettyPrinter.append("${name.value} = ")
        value.prettyPrint()
    }

    public prop name: Token {
        get() { name_ }
    }

    public prop value: Expr {
        get() { value_ }
    }
}

public class RefExpr <: Expr {
    private var identifier_: Token

    public RefExpr(identifier: Token) {
        identifier_ = identifier
    }

    public prop identifier: Token {
        get() { identifier_ }
    }

    public override func prettyPrint(): Unit {
        PrettyPrinter.append(identifier.value)
    }
}

public class Block <: Expr {
    private let nodes_: Array<Node>

    public Block(statements: Array<Node>) {
        super()
        nodes_ = statements
    }

    public override func prettyPrint() {
        PrettyPrinter.append("{")
        PrettyPrinter.indent()
        PrettyPrinter.append("\n")
        nodes.iterator().forEach({ 
            n =>    n.prettyPrint() 
                    PrettyPrinter.append("\n")
            })
        PrettyPrinter.unindent()
        PrettyPrinter.append("\n}\n")
    }

    public prop nodes: Array<Node> {
        get() { nodes_ }
    }
}

public class IfExpr <: Expr {
    private let condition_: Expr
    private let ifBlock_: Block
    private let elseBranch_: ?Expr

    public init(condition: Expr, ifBlock: Block) {
        this(condition, ifBlock, None)
    }

    public IfExpr(condition: Expr, ifBlock: Block, elseBranch: ?Expr) {
        super()
        condition_ = condition
        ifBlock_ = ifBlock
        elseBranch_ = elseBranch
    }

    public override func prettyPrint() {
        PrettyPrinter.append("if (")
        condition.prettyPrint()
        PrettyPrinter.append(") ")
        ifBlock.prettyPrint()
        if (let Some(eb) <- elseBranch) {
            PrettyPrinter.append("else ")
            eb.prettyPrint()
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

    public WhileExpr(condition: Expr, block: Block) {
        super()
        condition_ = condition
        block_ = block
    }

    public override func prettyPrint() {
        PrettyPrinter.append("while (")
        condition.prettyPrint()
        PrettyPrinter.append(") ")
        block.prettyPrint()
    }

    public prop condition: Expr {
        get() { condition_ }
    }

    public prop block: Block {
        get() { block_ }
    }
}

public class CallExpr <: Expr {
    private let callee_: Node
    private let arguments_: ArrayList<Argument>

    public CallExpr(callee: Node, arguments: ArrayList<Argument>) {
        callee_ = callee
        arguments_ = arguments
    }

    public override func prettyPrint(): Unit {
        callee.prettyPrint()
        PrettyPrinter.append("(")
        if (!arguments.isEmpty()) {
            arguments[0].prettyPrint()
            arguments.iterator().enumerate().filter({ a => a[0] > 0}).map({ a => a[1] })
                .forEach({ a => PrettyPrinter.append(", "); a.prettyPrint()})
        }
        PrettyPrinter.append(")")
    }

    public prop callee: Node {
        get() { callee_ }
    }

    public prop arguments: ArrayList<Argument> {
        get() { arguments_ }
    }
}

public class ReturnExpr <: Expr {
    private let value_: Expr 
    private let keyword_: Token

    public ReturnExpr(value: Expr, keyword: Token) {
        value_ = value
        keyword_ = keyword
    }

    public override func prettyPrint(): Unit {
        PrettyPrinter.append(keyword.value + " ")
        value.prettyPrint()
    }

    public prop value: Expr {
        get() { value_ }
    }

    public prop keyword: Token {
        get() { keyword_ }
    }
}
