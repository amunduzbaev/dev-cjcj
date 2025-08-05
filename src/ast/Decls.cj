package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter

// Temporary imports to not have compilation errors.
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.ast.Position
import std.collection.ArrayList

public abstract class Decl <: Node {
    // TODO: Use the default token constructor.
    protected var identifier_: Token = Token(TokenKind.ILLEGAL, "", Position())
    protected var keyword_: Token = identifier_

    init() { }

    init(identifier: Token, keyword: Token) {
        identifier_ = identifier
        keyword_ = keyword
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

    public override open func prettyPrint() {
        PrettyPrinter.append("${if (keyword.kind != TokenKind.ILLEGAL) {keyword.value + " "} else {""}}${identifier.value} ")
    }
}

public class VarDecl <: Decl {
    private var initializer_: ?Expr

    init (keyword: Token, identifier: Token) {
        this(keyword, identifier, None)
    }

    public init(keyword: Token, identifier: Token, initializer: ?Expr) {
        super(keyword, identifier)
        initializer_ = initializer
    }

    public mut prop initializer: ?Expr {
        get() { initializer_ }
        set(v) { initializer_ = v }
    }

    public override func prettyPrint() {
        super.prettyPrint()
        PrettyPrinter.append("${if (initializer.isSome()) {"= "} else {""}}")
        if (let Some(ini) <- initializer) {ini.prettyPrint()}
    }
}

public class FuncParam <: Decl {
    let paramType: TypeNode

    public init(paramType: TypeNode) {
        super()
        this.paramType = paramType
    }

    public override func prettyPrint() {
        paramType.prettyPrint()
    }
}

public class FuncDecl <: Decl {
    let block: Block
    let params: ArrayList<FuncParam>

    public init(identifier: Token, block: Block, params: ArrayList<FuncParam>) {
        this.block = block
        this.params = params
        this.identifier = identifier
    }

    public override func prettyPrint() {
        PrettyPrinter.append("func ")
        super.prettyPrint()
        PrettyPrinter.append("(")
        if (!params.isEmpty()) {
            params[0].prettyPrint()
            for (i in 1..params.size) {
                PrettyPrinter.append(", ")
                params[i].prettyPrint()
            }
        }
        PrettyPrinter.append(") ")
        block.prettyPrint()
    }
}
