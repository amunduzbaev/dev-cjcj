package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.*

import std.ast.Position

public open class TypeNode <: Node {
    private var typeParameterName_: Token = Token(TokenKind.ILLEGAL, "",
                                                    Position())

    public init() { }

    public init(typeParameterName: Token) {
        typeParameterName_ = typeParameterName
    }

    public override open func prettyPrint() {
        // PrettyPrinter.append(typeParameterName.value)
    }

    public mut prop typeParameterName: Token {
        get() { typeParameterName_ }
        set(v) { typeParameterName_ = v }
    }
}

public class PrimitiveType <: TypeNode {
    // Keyword for constructing a primitive type.
    private let keyword_: Token

    public init(typeParameterName: Token, keyword: Token) {
        keyword_ = keyword
        if (!isPrimitive(keyword)) {
            throw IllegalArgumentException(keyword.value +
                                            " is not a primitive type.")
        }
        super.typeParameterName = typeParameterName
    }

    public override func prettyPrint() {
        super.prettyPrint()
        PrettyPrinter.append(": " + keyword.value)
    }

    private func isPrimitive(keyword: Token): Bool {
        TokenKindHelper.PRIMITIVE_TYPE_TOKEN_KIND.iterator()
            .any({ t => t == keyword.kind })
    }

    public prop keyword: Token {
        get() { keyword_ }
    }
}