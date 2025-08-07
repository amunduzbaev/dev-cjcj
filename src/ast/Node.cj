package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.TokenKind
import cjcj.scanner.Token

import std.collection.ArrayList

public struct NodeId {
    public let id: UInt64

    public NodeId(id: UInt64) {
        this.id = id
    }
}

abstract sealed class Node {
    private let id_: NodeId

    public Node(id: NodeId) {
        id_ = id
    }
    // public func traverse(v: Visitor): Unit

    public func prettyPrint(printer: PrettyPrinter): Unit


    public prop id: NodeId {
        get() { id_ }
    }
}

public class Argument <: Node {
    let expr: Node

    public Argument(id: NodeId, expr: Node) {
        super(id)
        this.expr = expr
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        expr.prettyPrint(printer)
    }
}

public class Modifier <: Node {
    private let keyword_: Token

    public init(id: NodeId, keyword: Token) {
        super(id)
        keyword_ = keyword
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append(keyword.value)
    }

    public prop keyword: Token {
        get() { keyword_ }
    }
}