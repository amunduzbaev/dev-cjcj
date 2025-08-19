package cjcj.parser

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.scanner.TokenKindHelper

import std.collection.ArrayList
import std.convert.Parsable

public class Parser {
    private let declParser: DeclParser
    private let parserHelper: ParserHelper

    public Parser(private let tokens: Array<Token>,
                    private let reporter: Reporter) {
        this.parserHelper = ParserHelper(tokens, reporter)
        this.declParser = DeclParser(parserHelper)
    }

    public func parse(): ?Program {
        try {
            var nodes: ArrayList<Decl> = ArrayList()
            parserHelper.endStar()

            while (let Some(Obj) <- declParser.topLevelObject()) {
                nodes.add(Obj)
                parserHelper.endPlus("Expected end of TopLevelObject")
            }

            parserHelper.consume(TokenKind.MAIN, "Expected main declaration")
            nodes.add(declParser.mainDefinition())

            while (!parserHelper.isAtEnd()) {
                parserHelper.endPlus("Expected NL or SEMI after declaration")
                if(let Some(Obj) <- declParser.topLevelObject()) {
                    nodes.add(Obj)
                }
            }

            return Program(NodeIdManager.nextId(), nodes)
        } catch (_) {
            return None
        }
    }
}
