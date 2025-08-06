package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.*

import std.ast.Position

public open class TypeNode <: Node {
    var typeParameterName: Token = Token(TokenKind.ILLEGAL, "", Position())

    public init() { }

    public init(typeParameterName: Token) {
        this.typeParameterName = typeParameterName
    }

    public override open func prettyPrint() {
        // PrettyPrinter.append(typeParameterName.value)
    }
}

public class PrimitiveType <: TypeNode {
    // Keyword for constructing a primitive type.
    let keyword: Token

    public init(typeParameterName: Token, keyword: Token) {
        this.typeParameterName = typeParameterName
        this.keyword = keyword
        if (!isPrimitive(keyword)) {
            throw IllegalArgumentException(keyword.value + " is not a primitive type.")
        }
    }

    public override func prettyPrint() {
        super.prettyPrint()
        PrettyPrinter.append(": " + keyword.value)
    }

    private func isPrimitive(keyword: Token): Bool {
        TokenKindHelper.PRIMITIVE_TYPE_TOKEN_KIND.iterator().any({ t => t == keyword.kind })
    }
}