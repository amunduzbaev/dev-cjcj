package cjcj.ast

import cjcj.printUtils.PrintUtils

// Temporary imports to not have compilation errors.
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

public abstract class Decl <: Node {
    protected var identifier_: Token
    protected var keyword_: Token

    init (keyword: Token, identifier: Token) {
        super()
        identifier_ = identifier
        keyword_ = keyword
    }

    // Copy constructor
    init (decl: Decl) {
        super()
        this.identifier_ = decl.identifier_
        this.keyword_ = decl.keyword_
    }

    public mut open prop identifier: Token {
        get() { identifier_ }
        set(v) { identifier_ = v }
    }
    public mut open prop keyword: Token {
        get() { keyword_ }
        set(v) { keyword_ = v }
    }
}

public class VarDecl <: Decl {
    private var initializer_: ?Expr

    init (keyword: Token, identifier: Token) {
        this(keyword, identifier, None)
    }

    public init (keyword: Token, identifier: Token, initializer: ?Expr) {
        super(keyword, identifier)
        initializer_ = initializer
    }

    public mut prop initializer: ?Expr {
        get() { initializer_ }
        set(v) { initializer_ = v }
    }

    public override func prettyPrint(indent!: Int64 = 0): String {
        return """
VarDecl {
${PrintUtils.indent(indent)}    identifier: ${identifier.value}
${PrintUtils.indent(indent)}    keyword: ${keyword.value}
${PrintUtils.indent(indent)}    initializer: ${if (initializer.isSome()) {initializer.getOrThrow().prettyPrint(indent: indent + 1)} else {""}}
"""
    }
}
