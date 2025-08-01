package cjcj.scanner

import std.ast.Position
import std.deriving.*

public class Token <: ToString {
    public let kind: TokenKind
    public let value: String
    public let pos: Position

    init(typ: TokenKind, value: String, pos: Position) {
        this.kind = typ;
        this.value = value;
        this.pos = pos;
    }

    public func toString(): String {
        
        return "${kind} ${value} "
        
    }

}