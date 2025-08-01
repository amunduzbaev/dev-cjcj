package cjcj.ast

import cjcj.printUtils.PrintUtils

// Temporary imports to not have compilation errors.
import std.ast.Token
import std.ast.TokenKind

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

    public override func prettyPrint(indent!: Int64 = 0): String {
        return """
Binary {
${PrintUtils.indent(indent)}    left: ${left.prettyPrint(indent: indent + 1)}
${PrintUtils.indent(indent)}    operator: ${oper.value}
${PrintUtils.indent(indent)}    right: ${right.prettyPrint(indent: indent + 1)}
${PrintUtils.indent(indent)}}
"""
    }
}

public class Grouping <: Expr {
    let expression: Expr

    public Grouping(expression: Expr) {
        super()
        this.expression = expression
    }
    public override func prettyPrint(indent!: Int64 = 0): String {
        return """
Grouping {
${PrintUtils.indent(indent)}    expression: ${expression.prettyPrint(indent: indent + 1)}
${PrintUtils.indent(indent)}}
"""
    }
}

public class Literal <: Expr {
    let value: ?ToString

    public Literal(value: ?ToString) {
        super()
        this.value = value
    }

    public override func prettyPrint(indent!: Int64 = 0): String {
        return """
Literal {
${PrintUtils.indent(indent)}    value: ${value}
${PrintUtils.indent(indent)}}
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

    public override func prettyPrint(indent!: Int64 = 0): String {
        return """
Unary {
${PrintUtils.indent(indent)}    operator: ${oper.value}
${PrintUtils.indent(indent)}    right: ${right.prettyPrint(indent: indent + 1)}
${PrintUtils.indent(indent)}}
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
