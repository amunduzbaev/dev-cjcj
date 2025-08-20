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

    /*
    * TODO: Change this definition if it's better to let the visitor visit the
    * subgraph.
    * Visits the subtree of which this node is the root.
    */
    public open func traverse<R>(v: Visitor<R>): R

    /*
    * Print the node and its children as a piece of Cangjie code.
    */
    public func prettyPrint(printer: PrettyPrinter): Unit

    public prop id: NodeId {
        get() { id_ }
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
        // if (v.needBreakTraverse()) { return }
        // expr.traverse(v)
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
        // decls.iterator().forEach({ d => d.traverse(v) })
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