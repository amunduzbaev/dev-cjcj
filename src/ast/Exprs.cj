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
    let left: Expr
    let oper: Token
    let right: Expr

    public Binary(left: Expr, oper: Token, right: Expr) {
        super()
        this.left = left
        this.oper = oper
        this.right = right
    }

    public override func prettyPrint(): String {
        return """
"""
    }
}

public class Grouping <: Expr {
    let expression: Expr

    public Grouping(expression: Expr) {
        super()
        this.expression = expression
    }
    public override func prettyPrint(): String {
        return """
"""
    }
}

public class Literal <: Expr {
    let value: ?ToString

    public Literal(value: ?ToString) {
        super()
        this.value = value
    }

    public override func prettyPrint(): String {
        return """
"""
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
        return """
"""
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
