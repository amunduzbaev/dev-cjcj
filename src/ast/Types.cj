package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.ast.Position

public open class TypeNode <: Node {
    var typeParameterName: Token = Token(TokenKind.ILLEGAL, "", Position())

    public init() { }

    public init(typeParameterName: Token) {
        this.typeParameterName = typeParameterName
    }

    public override open func prettyPrint() {
    }
}

public class PrimitiveType <: TypeNode {
    // Keyword for constructing a primitive type.
    let keyword: Token

    public init(typeParameterName: Token, keyword: Token) {
        this.typeParameterName = typeParameterName
        this.keyword = keyword
    }

    public override func prettyPrint() {
        super.prettyPrint()
        PrettyPrinter.append(": " + keyword.value)
    }
}