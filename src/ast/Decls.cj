package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter

import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.ast.Position
import std.collection.ArrayList

public abstract class Decl <: Node {
    protected var identifier_: Token = Token()
    protected var keyword_: Token = identifier_
    protected var modifiers_ = ArrayList<Modifier>()

    init(id: NodeId) { super(id) }

    init(id: NodeId, keyword: Token, identifier: Token, modifiers: ArrayList<Modifier>) {
        this(id)
        identifier_ = identifier
        keyword_ = keyword
        modifiers_ = modifiers
    }

    // Copy constructor
    init (decl: Decl) {
        this(decl.id)
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

    public mut open prop modifiers: ArrayList<Modifier> {
        get() { modifiers_ }
        set(v) { modifiers_ = v }
    }

    public override open func prettyPrint(printer: PrettyPrinter) {
        modifiers.iterator()
            .forEach({ m => m.prettyPrint(printer); printer.append(" ")})
        if (keyword.kind != TokenKind.ILLEGAL) {
            printer.append(keyword.value + " ")
        }
        printer.append(identifier.value)
    }
}

public class VarDecl <: Decl {
    private let initializer_: ?Expr
    private let declType_: ?TypeNode

    public init (id: NodeId, keyword: Token, identifier: Token) {
        this(id, keyword, identifier, None)
    }

    public init(id: NodeId, keyword: Token, identifier: Token, initializer: ?Expr) {
        this(id, keyword, identifier, initializer, ArrayList<Modifier>(), None)
    }

    public init(id: NodeId, keyword: Token, identifier: Token, initializer: ?Expr,
            modifiers: ArrayList<Modifier>, declType: ?TypeNode) {
        super(id, keyword, identifier, modifiers)
        initializer_ = initializer
        declType_ = declType
    }

    public prop initializer: ?Expr {
        get() { initializer_ }
    }

    public prop declType: ?TypeNode {
        get() { declType_ }
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        if (let Some(dtype) <- declType) {
            dtype.prettyPrint(printer)
        }
        printer.append("${if (initializer.isSome()) {" = "} else {""}}")
        if (let Some(ini) <- initializer) {ini.prettyPrint(printer)}
    }
}

public class InitDecl <: Decl {
    private let block_: Block
    private let params_: ArrayList<FuncParam>

    public init(id: NodeId, keyword: Token, identifier: Token, block: Block,
                modifiers: ArrayList<Modifier>, params: ArrayList<FuncParam>) {
        super(id, keyword, identifier, modifiers)
        this.block_ = block
        this.params_ = params
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        printer.append("(")
        if (!params.isEmpty()) {
            params[0].prettyPrint(printer)
            for (i in 1..params.size) {
                printer.append(", ")
                params[i].prettyPrint(printer)
            }
        }
        printer.append(")")
        block_.prettyPrint(printer)
    }

    public prop block: Block {
        get() { block_ }
    }

    public prop params: ArrayList<FuncParam> {
        get() { params_ }
    }


}

public class FuncParam <: Decl {
    private let paramType_: TypeNode

    public init(id: NodeId, paramType: TypeNode) {
        super(id)
        paramType_ = paramType
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append(paramType.typeParameterName.value)
        paramType.prettyPrint(printer)
    }

    public prop paramType: TypeNode {
        get() { paramType_ }
    }
}

public class FuncDecl <: Decl {
    private let block_: Block
    private let params_: ArrayList<FuncParam>

    private let declType_: ?TypeNode

    public init(id: NodeId, keyword: Token, identifier: Token, block: Block,
                modifiers: ArrayList<Modifier>, params: ArrayList<FuncParam>,
                declType: ?TypeNode) {
        super(id, keyword, identifier, modifiers)
        this.block_ = block
        this.params_ = params
        this.declType_ = declType
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        printer.append("(")
        if (!params.isEmpty()) {
            params[0].prettyPrint(printer)
            for (i in 1..params.size) {
                printer.append(", ")
                params[i].prettyPrint(printer)
            }
        }
        printer.append(")")
        if (let Some(dtype) <- declType) {
            dtype.prettyPrint(printer)
        }
        block_.prettyPrint(printer)
    }

    public prop block: Block {
        get() { block_ }
    }

    public prop params: ArrayList<FuncParam> {
        get() { params_ }
    }

    public prop declType: ?TypeNode {
        get() { declType_ }
    }
}

public class ClassDecl <: Decl {
    private let block_: Block

    public init(id: NodeId, identifier: Token, block: Block) {
        super(id)
        block_ = block
        this.identifier = identifier
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        printer.append("class ")
        super.prettyPrint(printer)
        block.prettyPrint(printer)
    }

    public prop block: Block {
        get() { block_ }
    }
}

public class StructDecl <: Decl {
    private let block_: Block

    public StructDecl(id: NodeId, keyword: Token, identifier: Token,
                        modifiers: ArrayList<Modifier>, block: Block) {
        super(id, keyword, identifier, modifiers)
        block_ = block
    }

    public override func prettyPrint(printer: PrettyPrinter) {
        super.prettyPrint(printer)
        block.prettyPrint(printer)
    }

    public prop block: Block {
        get() { block_ }
    }
}
