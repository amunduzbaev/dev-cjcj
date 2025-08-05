package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

public open class TypeNode <: Node {
    let typeParameterName: Token

    public init(typeParameterName: Token) {
        this.typeParameterName = typeParameterName
    }

    public override open func prettyPrint() {
        PrettyPrinter.append(typeParameterName.value)
    }
}

public class PrimitiveType <: TypeNode {
    // Keyword for constructing a primitive type.
    let keyword: Token

    public init(typeParameterName: Token, keyword: Token) {
        super(typeParameterName)
        this.keyword = keyword
    }

    public override func prettyPrint() {
        super.prettyPrint()
        PrettyPrinter.append(": " + keyword.value)
    }
}