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
    * Visits the subtree of which this node is the root.
    */
    public func traverse(v: Visitor): Unit

    /*
    * Print the node and its children as a piece of Cangjie code.
    */
    public func prettyPrint(printer: PrettyPrinter): Unit

    public prop id: NodeId {
        get() { id_ }
    }
}

public class Argument <: Node {
    private let expr_: Node

    public Argument(id: NodeId, expr: Node) {
        super(id)
        expr_ = expr
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        if (v.needBreakTraverse()) { return }
        expr.traverse(v)
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        expr.prettyPrint(printer)
    }

    public prop expr: Node {
        get() { expr_ }
    }
}

public class Program <: Node {
    private let decls_: ArrayList<Decl>

    public Program(id: NodeId, decls: ArrayList<Decl>) {
        super(id)
        decls_ = decls
    }

    public override func traverse(v: Visitor): Unit {
        v.visit(this)
        decls.iterator().forEach({ d => d.traverse(v) })
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        decls.iterator().forEach({
            d => d.prettyPrint(printer)
            printer.append("\n")
        })
    }

    public prop decls: ArrayList<Decl> {
        get() { decls_ }
    }
}