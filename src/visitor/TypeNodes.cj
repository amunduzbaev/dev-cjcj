package cjcj.visitor

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.*

import std.ast.Position

/*
    TODO: Make this abstract and try to remove the default constructors of the nodes that maybe we
    can avoid.
*/
public open class TypeNode <: Node {
    private var typeParameterName_: Token = Token()
    private var typeName_: Token = Token()
    
    public init() {
        this(NodeId())
    }

    public init(id: NodeId) {
        super(id)
    }

    public init(id: NodeId, typeParameterName: Token, typeName: Token) {
        super(id)
        typeParameterName_ = typeParameterName
        typeName_ = typeName
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

    public mut prop typeName: Token {
        get() { typeName_ }
        set(v) { typeName_ = v }
    }
}

public class PrimitiveType <: TypeNode {

    public init(id: NodeId, typeParameterName: Token, typeName: Token) {
        super(id, typeParameterName, if (isPrimitive(typeName)) {
                typeName
            } else {
                throw IllegalArgumentException("${typeName.value} is not a primitive type.")
            }
        )
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        printer.append(": " + typeName.value)
    }

    private func isPrimitive(typeName: Token): Bool {
        TokenKindHelper.CHAR_LANG_TYPES.iterator()
            .any({ t => t == typeName.kind })
    }
}

public class RefType <: TypeNode {

    public init(id: NodeId, typeParameterName: Token, typeName: Token) {
        super(id, typeParameterName, typeName)
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        printer.append(": " + typeName.value)
    }
}