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
    let left: Node
    let oper: Token
    let right: Node

    public Binary(left: Node, oper: Token, right: Node) {
        super()
        this.left = left
        this.oper = oper
        this.right = right
    }

    public override func prettyPrint() {
        left.prettyPrint()
        PrettyPrinter.append(" ${oper.value} ")
        right.prettyPrint()
    }
}

public class Logical <: Expr {
    let left: Node
    let oper: Token
    let right: Node

    public Logical(left: Node, oper: Token, right: Node) {
        super()
        this.left = left
        this.oper = oper
        this.right = right
    }

    public override func prettyPrint() {
        left.prettyPrint()
        PrettyPrinter.append(" ${oper.value} ")
        right.prettyPrint()
    }
}

public class Grouping <: Expr {
    let node: Node

    public Grouping(node: Node) {
        super()
        this.node = node
    }
    public override func prettyPrint() {
        PrettyPrinter.append("(")
        node.prettyPrint()
        PrettyPrinter.append(")")
    }
}

public class Literal <: Expr {
    let value: ?ToString

    public Literal(value: ?ToString) {
        super()
        this.value = value
    }

    public override func prettyPrint() {
        PrettyPrinter.append("${if (let Some(s) <- value) {s.toString()} else {""}}")
    }
}

public class Unary <: Expr {
    let oper: Token
    let right: Expr

    public Unary(oper: Token, right: Expr) {
        super()
        this.oper = oper
        this.right = right
    }

    public override func prettyPrint() {
        PrettyPrinter.append("${oper.toString()}")
        right.prettyPrint()
    }
}

public class Assign <: Expr {
    let name: Token
    let value: Expr

    public Assign(name: Token, value: Expr) {
        super()
        this.name = name
        this.value = value
    }

    public override func prettyPrint() {
        PrettyPrinter.append("${name.value} = ")
        value.prettyPrint()
    }
}

public class Block <: Expr {
    let nodes: Array<Node>

    public Block(statements: Array<Node>) {
        super()
        this.nodes = statements
    }

    public override func prettyPrint() {
        PrettyPrinter.append("{")
        PrettyPrinter.indent()
        PrettyPrinter.append("\n")
        nodes.iterator().forEach({ n => n.prettyPrint() })
        PrettyPrinter.unindent()
        PrettyPrinter.append("\n}\n")
    }
}

public class IfExpr <: Expr {
    let condition: Expr
    let ifBlock: Block
    let elseBranch: ?Expr

    public init(condition: Expr, ifBlock: Block) {
        this(condition, ifBlock, None)
    }

    public IfExpr(condition: Expr, ifBlock: Block, elseBranch: ?Expr) {
        super()
        this.condition = condition
        this.ifBlock = ifBlock
        this.elseBranch = elseBranch
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
}

public class WhileExpr <: Expr {
    let condition: Expr 
    let block: Block

    public WhileExpr(condition: Expr, block: Block) {
        super()
        this.condition = condition
        this.block = block
    }

    public override func prettyPrint() {
        PrettyPrinter.append("while (")
        condition.prettyPrint()
        PrettyPrinter.append(")")
        block.prettyPrint()
    }
}

public class CallExpr <: Expr {
    let callee: Node
    let arguments: ArrayList<Argument>

    public CallExpr(callee: Node, arguments: ArrayList<Argument>) {
        this.callee = callee
        this.arguments = arguments
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
}

public class ReturnExpr <: Expr {
    let value: Node 
    let keyword: Token

    public init(value: Node, keyword: Token) {
        this.value = value
        this.keyword = keyword
        // TODO: Add exception for keyword not return
    }

    public override func prettyPrint(): Unit {
        PrettyPrinter.append(keyword.value + " ")
        value.prettyPrint()
    }
}
