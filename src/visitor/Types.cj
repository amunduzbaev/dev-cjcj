package cjcj.visitor

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.*

import std.ast.Position

public open class TypeNode <: Node {
    private var typeParameterName_: Token = Token(TokenKind.ILLEGAL, "",
                                                    Position())

    public init() {
        this(NodeId())
    }

    public init(id: NodeId) {
        super(id)
    }

    public init(id: NodeId, typeParameterName: Token) {
        this(id)
        typeParameterName_ = typeParameterName
    }

    public override open func traverse<R>(v: Visitor<R>): R  {
        v.visit(this)
    }

    public override open func prettyPrint(_: PrettyPrinter): Unit {
    }

    public mut prop typeParameterName: Token {
        get() { typeParameterName_ }
        set(v) { typeParameterName_ = v }
    }
}

public class PrimitiveType <: TypeNode {
    // Keyword for constructing a primitive type.
    private var keyword_: Token

    public init() {
        this(NodeId(), Token(), Token())
    }

    public init(id: NodeId, typeParameterName: Token, keyword: Token) {
        super(id)
        keyword_ = keyword
        if (!isPrimitive(keyword)) {
            throw IllegalArgumentException(keyword.value +
                                            " is not a primitive type.")
        }
        super.typeParameterName = typeParameterName
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        printer.append(": " + keyword.value)
    }

    private func isPrimitive(keyword: Token): Bool {
        TokenKindHelper.CHAR_LANG_TYPES.iterator()
            .any({ t => t == keyword.kind })
    }

    public mut prop keyword: Token {
        get() { keyword_ }
        set(v) { keyword_ = v }
    }
}

public class RefType <: TypeNode {
    private var identifier_: Token

    public init() {
        this(NodeId(), Token(), Token())
    }

    public init(id: NodeId, typeParameterName: Token, identifier: Token) {
        super(id, typeParameterName)
        identifier_ = identifier
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        printer.append(": " + identifier.value)
    }

    public mut prop identifier: Token {
        get() { identifier_ }
        set(v) { identifier_ = v }
    }
}