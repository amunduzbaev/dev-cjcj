package cjcj.visitor

// import cjcj.ast.Node
// import cjcj.ast.Expr
// import cjcj.ast.Block
// import cjcj.ast.TypeNode
// import cjcj.ast.FuncParam
// import cjcj.ast.Argument
// import cjcj.ast.NodeId
// import cjcj.ast.Visitor
import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
// import cjcj.asg.Environment
// import cjcj.parser.ParseError
// import cjcj.ast.VarDecl

import std.collection.ArrayList

/*
* Reference nodes represent references to variables, functions, . . . inside the
* ASG.
*/
public open class Reference <: Node & Hashable & Equatable<Reference> {
    /*
    TODO: the identifier will become an expression and in general all the
    * references will be checked by hashing the toString of the expression that
    * is calling, this is important because it can happen that I call a function
    * from a member access (a.b()) and I need to differenciate between them
    * (b() must be different from a.b()).
    */
    private let identifier_: Token
    private let declType_: ?TypeNode

    public Reference(id: NodeId, identifier: Token, declType: ?TypeNode) {
        super(id)
        identifier_ = identifier
        declType_ = declType
    }

    public override open func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append(identifier.value)
    }

    public override func traverse<R>(_: Visitor<R>): R {
        throw UnsupportedException("Unimplemented method")
    }

    public func hashCode(): Int64 {
        this.id.hashCode()
    }
    public operator func == (rhs: Reference) :Bool{
        id.id == rhs.id.id
    }

    public prop identifier: Token {
        get() { identifier_ }
    }

    public prop declType: ?TypeNode {
        get() { declType_ }
    }
}

public class VariableReference <: Reference {
    private let keyword_: Token

    public init(id: NodeId, identifier: Token, declType: ?TypeNode,
        keyword: Token) {
        super(id, identifier, declType)
        keyword_ = keyword
    }

    public prop keyword: Token {
        get() { keyword_ }
    }
}

public class FuncReference <: Reference {
    private let environment_: Environment
    private let params_: ArrayList<FuncParam>

    public FuncReference(id: NodeId, identifier: Token, declType: ?TypeNode,
        environment: Environment, params: ArrayList<FuncParam>) {
        super(id, identifier, declType)
        environment_ = environment
        params_ = params
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        super.prettyPrint(printer)
    }

    public prop environment: Environment {
        get() { environment_ }
    }

    public prop params: ArrayList<FuncParam> {
        get() { params_ }
    }
}


public class VarDeclWithRef <: VarDecl {
    private let ref_: Reference

    public init (id: NodeId, keyword: Token, identifier: Token, ref: Reference) {
        this(id, keyword, identifier, ref, None)
    }

    public init(id: NodeId, keyword: Token, identifier: Token, ref: Reference, initializer: ?Expr) {
        this(id, keyword, identifier, ref, initializer, None)
    }

    public init(id: NodeId, keyword: Token, identifier: Token, ref: Reference, initializer: ?Expr,
            declType: ?TypeNode) {
        super(id, keyword, identifier, initializer, declType)
        ref_ = ref
    }

    public prop ref : Reference {
        get() { ref_ }
    }
}