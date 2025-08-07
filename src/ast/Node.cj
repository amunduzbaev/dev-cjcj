package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.TokenKind
import cjcj.scanner.Token

import std.collection.ArrayList

abstract sealed class Node {
    // public func traverse(v: Visitor): Unit
    public func prettyPrint(): Unit
}

public class Argument <: Node {
    let expr: Node

    public Argument(expr: Node) {
        this.expr = expr
    }

    public override func prettyPrint(): Unit {
        expr.prettyPrint()
    }
}

public class Modifier <: Node {
    private let keyword_: Token

    public init(keyword: Token) {
        keyword_ = keyword
    }

    public override func prettyPrint(): Unit {
        PrettyPrinter.append(keyword.value)
    }

    public prop keyword: Token {
        get() { keyword_ }
    }
}