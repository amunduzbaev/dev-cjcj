package cjcj.ast

import std.collection.ArrayList

/** Temporary imports while waiting for the scanner */
import std.ast.TokenKind
import std.ast.Token

enum StringKind {
    NORMAL | JSTRING | MULTILINE | MULTILINE_RAW
}

abstract sealed class Node {
    // public func traverse(v: Visitor): Unit
    public func prettyPrint(indent!: Int64): String
}

// public class Program <: Node {
//     private var decls_: ArrayList<Decl>

//     init (decls: ArrayList<Decl>) {
//         super()
//         decls_ = decls
//     }

//     public mut prop decls: ArrayList<Decl> {
//         get() { decls_ }
//         set(v) { decls_ = v }
//     }
// }
