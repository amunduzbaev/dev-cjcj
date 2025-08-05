package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.TokenKind
import cjcj.scanner.Token

import std.collection.ArrayList

enum StringKind {
    NORMAL | JSTRING | MULTILINE | MULTILINE_RAW
}

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

// public class Program <: Node {
//     private var decls_: ArrayList<Decl>

//     public init (decls: ArrayList<Decl>) {
//         super()
//         decls_ = decls
//     }

//     public mut prop decls: ArrayList<Decl> {
//         get() { decls_ }
//         set(v) { decls_ = v }
//     }

//     public override func prettyPrint(): String {
//         ""
//     }
// }
