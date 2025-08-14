package cjcj.parser

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.scanner.TokenKindHelper

import std.collection.ArrayList
import std.convert.Parsable

public class Parser {
    private let tokens: Array<Token>
    private let reporter: Reporter
    private let exprParser: ExprParser

    public Parser(tokens: Array<Token>, reporter: Reporter) {
        this.tokens = tokens
        this.reporter = reporter
        this.exprParser = ExprParser(tokens)
    }

    public func parse(): ?Array<Node> {
        let nodes: ArrayList<Node> = ArrayList()
        exprParser.skipNL()
        while (!exprParser.isAtEnd()) {
            nodes.add(exprParser.expression())
            exprParser.skipNL()
        }
        return nodes.toArray()
    }
}
