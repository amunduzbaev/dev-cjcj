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