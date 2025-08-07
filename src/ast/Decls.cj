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

    init() { }

    init(keyword: Token, identifier: Token, modifiers: ArrayList<Modifier>) {
        identifier_ = identifier
        keyword_ = keyword
        modifiers_ = modifiers
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

    public mut open prop modifiers: ArrayList<Modifier> {
        get() { modifiers_ }
        set(v) { modifiers_ = v }
    }

    public override open func prettyPrint() {
        modifiers.iterator()
            .forEach({ m => m.prettyPrint(); PrettyPrinter.append(" ")})
        if (keyword.kind != TokenKind.ILLEGAL) {
            PrettyPrinter.append(keyword.value + " ")
        }
        PrettyPrinter.append(identifier.value)
    }
}

public class VarDecl <: Decl {
    private let initializer_: ?Expr
    private let declType_: ?TypeNode

    public init (keyword: Token, identifier: Token) {
        this(keyword, identifier, None)
    }

    public init(keyword: Token, identifier: Token, initializer: ?Expr) {
        this(keyword, identifier, initializer, ArrayList<Modifier>(), None)
    }

    public init(keyword: Token, identifier: Token, initializer: ?Expr,
            modifiers: ArrayList<Modifier>, declType: ?TypeNode) {
        super(keyword, identifier, modifiers)
        initializer_ = initializer
        declType_ = declType
    }

    public prop initializer: ?Expr {
        get() { initializer_ }
    }

    public prop declType: ?TypeNode {
        get() { declType_ }
    }

    public override func prettyPrint() {
        super.prettyPrint()
        if (let Some(dtype) <- declType) {
            dtype.prettyPrint()
        }
        PrettyPrinter.append("${if (initializer.isSome()) {" = "} else {""}}")
        if (let Some(ini) <- initializer) {ini.prettyPrint()}
    }
}

public class InitDecl <: Decl {
    private let block_: Block
    private let params_: ArrayList<FuncParam>

    public init(keyword: Token, identifier: Token, block: Block,
                modifiers: ArrayList<Modifier>, params: ArrayList<FuncParam>) {
        super(keyword, identifier, modifiers)
        this.block_ = block
        this.params_ = params
    }

    public override func prettyPrint() {
        super.prettyPrint()
        PrettyPrinter.append("(")
        if (!params.isEmpty()) {
            params[0].prettyPrint()
            for (i in 1..params.size) {
                PrettyPrinter.append(", ")
                params[i].prettyPrint()
            }
        }
        PrettyPrinter.append(")")
        block_.prettyPrint()
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

    public init(paramType: TypeNode) {
        super()
        paramType_ = paramType
    }

    public override func prettyPrint() {
        PrettyPrinter.append(paramType.typeParameterName.value)
        paramType.prettyPrint()
    }

    public prop paramType: TypeNode {
        get() { paramType_ }
    }
}

public class FuncDecl <: Decl {
    private let block_: Block
    private let params_: ArrayList<FuncParam>

    private let declType_: ?TypeNode

    public init(keyword: Token, identifier: Token, block: Block,
                modifiers: ArrayList<Modifier>, params: ArrayList<FuncParam>,
                declType: ?TypeNode) {
        super(keyword, identifier, modifiers)
        this.block_ = block
        this.params_ = params
        this.declType_ = declType
    }

    public override func prettyPrint() {
        super.prettyPrint()
        PrettyPrinter.append("(")
        if (!params.isEmpty()) {
            params[0].prettyPrint()
            for (i in 1..params.size) {
                PrettyPrinter.append(", ")
                params[i].prettyPrint()
            }
        }
        PrettyPrinter.append(")")
        if (let Some(dtype) <- declType) {
            dtype.prettyPrint()
        }
        block_.prettyPrint()
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

    public init(identifier: Token, block: Block) {
        block_ = block
        this.identifier = identifier
    }

    public override func prettyPrint() {
        PrettyPrinter.append("class ")
        super.prettyPrint()
        block.prettyPrint()
    }

    public prop block: Block {
        get() { block_ }
    }
}

public class StructDecl <: Decl {
    private let block_: Block

    public StructDecl(keyword: Token, identifier: Token,
                        modifiers: ArrayList<Modifier>, block: Block) {
        super(keyword, identifier, modifiers)
        block_ = block
    }

    public override func prettyPrint() {
        super.prettyPrint()
        block.prettyPrint()
    }

    public prop block: Block {
        get() { block_ }
    }
}
