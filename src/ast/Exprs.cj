package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

public abstract class Expr <: Node {
    init() {
        super()
    }
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

    public override func prettyPrint(): String {
        left.prettyPrint()
        PrettyPrinter.append(" ${oper.value} ")
        right.prettyPrint()
        ""
    }
}

public class Grouping <: Expr {
    let node: Node

    public Grouping(node: Node) {
        super()
        this.node = node
    }
    public override func prettyPrint(): String {
        PrettyPrinter.append("(")
        node.prettyPrint()
        PrettyPrinter.append(")")
        ""
    }
}

public class Literal <: Expr {
    let value: ?ToString

    public Literal(value: ?ToString) {
        super()
        this.value = value
    }

    public override func prettyPrint(): String {
        PrettyPrinter.append("${if (let Some(s) <- value) {s.toString()} else {""}}")
        ""
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

    public override func prettyPrint(): String {
        PrettyPrinter.append("${oper.toString()}")
        right.prettyPrint()
        ""
    }
}

public class Assign <: Expr {
    let name: Token
    let value: Expr

    public Assign(name: Token, value: Expr) {
        this.name = name
        this.value = value
    }

    public override func prettyPrint(): String {
        PrettyPrinter.append("${name.value} = ")
        value.prettyPrint()
        ""
    }
}

public class Block <: Expr {
    let nodes: Array<Node>

    public Block(statements: Array<Node>) {
        this.nodes = statements
    }

    public override func prettyPrint(): String {
        PrettyPrinter.append("{")
        PrettyPrinter.indent()
        PrettyPrinter.append("\n")
        nodes.iterator().forEach({ n => n.prettyPrint() })
        PrettyPrinter.unindent()
        PrettyPrinter.append("\n}\n")
        ""
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
        this.condition = condition
        this.ifBlock = ifBlock
        this.elseBranch = elseBranch
    }

    public override func prettyPrint(): String {
        PrettyPrinter.append("if (")
        condition.prettyPrint()
        PrettyPrinter.append(") ")
        ifBlock.prettyPrint()
        if (let Some(eb) <- elseBranch) {
            PrettyPrinter.append("else ")
            eb.prettyPrint()
        }
        ""
    }
}

public class WhileExpr <: Expr {
    let condition: Expr 
    let block: Block

    public WhileExpr(condition: Expr, block: Block) {
        this.condition = condition
        this.block = block
    }

    public override func prettyPrint(): String {
        PrettyPrinter.append("while (")
        condition.prettyPrint()
        PrettyPrinter.append(")")
        block.prettyPrint()
        ""
    }
}

// public class Variable <: Expr {
//     let name: Token
//     let isMutable: Bool

//     public Variable(name: Token, isMutable: Bool) {
//         super()
//         this.name = name
//         this.isMutable = isMutable
//     }

//     public override func prettyPrint(): String {
//         return """
// {
//     left: ${left.prettyPrint()}
//     operator: ${oper.value}
//     right: ${right.prettyPrint()}
// }
// """
//     }
// }
