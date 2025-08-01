package cjcj.ast

import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

public abstract class Pattern <: Node { }

public class VarPattern <: Pattern {
    private var identifier_: Token

    public VarPattern(identifier: Token) {
        identifier_ = identifier
    }

    public mut prop identifier: Token {
        get() { identifier_ }
        set(v) { identifier_ = v }
    }

    public override func prettyPrint() {
        PrettyPrinter.append(identifier.value)
        ""
    }
}
