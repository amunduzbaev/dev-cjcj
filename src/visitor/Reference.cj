package cjcj.visitor

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.collection.ArrayList

/*
* Reference nodes represent references to variables, functions, . . . inside the
* ASG.
*/
public open class Reference <: Expr & Hashable & Equatable<Reference> {
    /*
    TODO: the identifier will become an expression and in general all the
    * references will be checked by hashing the toString of the expression that
    * is calling, this is important because it can happen that I call a function
    * from a member access (a.b()) and I need to differenciate between them
    * (b() must be different from a.b()).
    */
    private let identifier_: Token
    private let declType_: ?TypeNode
    private var effectiveType_: ?Type

    public Reference(id: NodeId, identifier: Token, declType: ?TypeNode, effectiveType: ?Type) {
        super(id)
        identifier_ = identifier
        declType_ = declType
        effectiveType_ = effectiveType
    }

    public override open func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append(identifier.value)
    }

    public override open func traverse<R>(_: Visitor<R>): R {
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

    public mut prop effectiveType: ?Type {
        get() { effectiveType_ }
        set(v) { effectiveType_ = v }
    }
}

public class VariableReference <: Reference {
    private let keyword_: Token

    public init(id: NodeId, identifier: Token, declType: ?TypeNode,
        keyword: Token) {
        super(id, identifier, declType, None)
        keyword_ = keyword
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public prop keyword: Token {
        get() { keyword_ }
    }
}

public class FuncReference <: Reference {
    // TODO: Maybe environment can be removed.
    private let environment_: Environment
    private let params_: ArrayList<FuncParam>

    public FuncReference(id: NodeId, identifier: Token, declType: ?TypeNode,
        environment: Environment, params: ArrayList<FuncParam>) {
        super(id, identifier, declType, None)
        environment_ = environment
        params_ = params
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
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

public class ClassReference <: Reference{
    // I don't think we need to body here, because even if we include the body, we have to 
    // process it in order to be able to check if the member exists or not
    // So better alternative solution is to preprocess the members for each class at declaration 
    public init(id: NodeId, identifier: Token, declType: ?TypeNode) {
        super(id, identifier, declType, None)
    }
    public init(id: NodeId, identifier: Token) {
        super(id, identifier, None, None)
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }
}

/*
    TODO: The following classes may be a temporary solution until we find a cleaner way to handle
    this kind of problem.
*/
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

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public prop ref : Reference {
        get() { ref_ }
    }
}

public class FuncDeclWithRef <: FuncDecl {
    // TODO: Maybe the list of parameters can be removed
    private let paramRef_: ArrayList<Reference>
    private let funcRef_: FuncReference

    public init(id: NodeId, keyword: Token, block: Block, params: ArrayList<FuncParam>,
            paramRef: ArrayList<Reference>, funcRef: FuncReference) {
        this(id, keyword, Token(), block, params, None, paramRef, funcRef)
    }

    public FuncDeclWithRef(id: NodeId, keyword: Token, identifier: Token, block: Block,
                params: ArrayList<FuncParam>, declType: ?TypeNode, paramRef: ArrayList<Reference>,
                funcRef: FuncReference) {
        super(id, keyword, identifier, block, params, declType)
        paramRef_ = paramRef
        funcRef_ = funcRef
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public prop paramRef : ArrayList<Reference> {
        get() { paramRef_ }
    }

    public prop funcRef: FuncReference {
        get() { funcRef_ }
    }
}

public class MainDeclWithRef <: MainDecl {
    private var paramRef_: ?Reference

    public MainDeclWithRef(id: NodeId, block: Block, param: ?FuncParam, 
                    declType: ?TypeNode, paramRef: ?Reference) {
        super(id, block, param, declType)
        paramRef_ = paramRef
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public mut prop paramRef : ?Reference {
        get() { paramRef_ }
        set(v) { paramRef_ = v }
    }
}

public class ClassDeclWithRef <: ClassDecl {
    private let ref_: Reference

    public init(id: NodeId, keyword: Token, identifier: Token, body: Body,
            superTypes: ArrayList<TypeNode>, ref: Reference) {
        super(id, keyword, identifier, body, superTypes)
        ref_ = ref
    }

    public override func traverse<R>(v: Visitor<R>): R {
        v.visit(this)
    }

    public prop ref : Reference {
        get() { ref_ }
    }
}