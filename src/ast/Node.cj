package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.TokenKind
import cjcj.scanner.Token

import std.collection.ArrayList

public struct NodeId {
    public let id: UInt64

    // Default initializer with a default ID.
    public init() {
        this(0)
    }

    public NodeId(id: UInt64) {
        this.id = id
    }
}

public abstract class Node {
    private var id_: NodeId

    public Node(id: NodeId) {
        id_ = id
    }

    /*
    TODO: Change this implementation to all classes if it's better to let the
    nodes traverse their subgraph on their own.
    */
    public func traverse<R>(v: Visitor<R>): R

    /*
    * Print the node and its children as a piece of Cangjie code.
    */
    public func prettyPrint(printer: PrettyPrinter): Unit

    public mut prop id: NodeId {
        get() { id_ }
        set(v) { id_ = v }
    }
}

public class Argument <: Node {
    private var expr_: Node

    public Argument(id: NodeId, expr: Node) {
        super(id)
        expr_ = expr
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        expr.prettyPrint(printer)
    }

    public mut prop expr: Node {
        get() { expr_ }
        set(v) { expr_ = v }
    }
}

public class Program <: Node {
    private var decls_: ArrayList<Decl>

    public Program(id: NodeId, decls: ArrayList<Decl>) {
        super(id)
        decls_ = decls
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        decls.iterator().forEach({
            d => d.prettyPrint(printer)
            printer.append("\n")
        })
    }

    public mut prop decls: ArrayList<Decl> {
        get() { decls_ }
        set(v) { decls_ = v }
    }
}