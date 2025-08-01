package cjcj.ast

import cjcj.scanner.TokenKind
import cjcj.scanner.Token

import std.collection.ArrayList

enum StringKind {
    NORMAL | JSTRING | MULTILINE | MULTILINE_RAW
}

abstract sealed class Node {
    // public func traverse(v: Visitor): Unit
    public func prettyPrint(): String
}

public class Program <: Node {
    private var decls_: ArrayList<Decl>

    init (decls: ArrayList<Decl>) {
        super()
        decls_ = decls
    }

    public mut prop decls: ArrayList<Decl> {
        get() { decls_ }
        set(v) { decls_ = v }
    }

    public override func prettyPrint(): String {
        ""
    }
}
