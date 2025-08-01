package CangjieCompiler

import std.ast.Position
import std.deriving.*

class Token <: ToString {

    let typ: TokenKind
    let value: String
    let pos: Position

    init(typ: TokenKind, value: String, pos: Position) {
        this.typ = typ;
        this.value = value;
        this.pos = pos;
    }

    public func toString(): String {
        
        return "${typ} ${value} "
        
    }

}