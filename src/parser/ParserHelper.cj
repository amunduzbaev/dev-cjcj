package cjcj.parser

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.scanner.TokenKindHelper

class ParseError <: Exception { }

class NodeIdManager {
    private static var count: UInt64 = 0

    public static func nextId(): NodeId {
        let id = NodeId(count)
        count++
        id
    }
}

class ParserHelper {
    var current: Int64
    private let tokens: Array<Token>

    public ParserHelper(tokens: Array<Token>, private let reporter: Reporter) {
        this.tokens = tokens
        current = 0
    }

    /*
    * Tries to skip the NL token and check if the next token is of the target
    * kind.
    * If it is, advance and returns true.
    * If it's not it goes back to before the NL and returns false.
    */
    func skipNLCompare(target: Array<TokenKind>): Bool {
        let tmp: Int64 = current
        skipNL()
        if (target.iterator().any({ t => check(t) })) {
            advance()
            return true
        }
        current = tmp
        return false
    }

    func advance(): Token {
        if (!isAtEnd()) {
            current++
        }
        previous()
    }

    func isAtEnd(): Bool {
        peek().kind == TokenKind.END
    }

    func peek(): Token {
        tokens[current]
    }

    func matches(types: Array<TokenKind>): Bool {
        for (kind in types) {
            if (check(kind)) {
                advance()
                return true
            }
        }
        return false
    }

    func check(kind: TokenKind): Bool {
        if (isAtEnd()) {
            return false
        }
        peek().kind == kind
    }

    func previous(): Token {
        tokens[current - 1]
    }

    func skipNL(): Unit {
        if (check(TokenKind.NL)) {
            advance()
        }
    }

    /**
    * When we find an error we don't want to break everything and stop parsing.
    * So we synchronize, we discard tokens until we find a statement boundary.
    */
    func synchronize(): Unit {
        advance()

        while (!isAtEnd()) {
            // Finished a statement
            if (previous().kind == TokenKind.SEMI ||
                previous().kind == TokenKind.NL
            ) {
                return
            }

            if (peek().kind == TokenKind.CLASS ||
                peek().kind == TokenKind.FUNC ||
                peek().kind == TokenKind.VAR ||
                peek().kind == TokenKind.IF ||
                peek().kind == TokenKind.WHILE ||
                peek().kind == TokenKind.RETURN ||
                peek().kind == TokenKind.STRUCT ||
                peek().kind == TokenKind.RPAREN
            ) {
                return
            }
            advance()
        }
    }

    func endStar(): Unit {
        while(matches(TokenKindHelper.END)) { }
    }

    func endPlus(message: String): Unit {
        if (matches(TokenKindHelper.END)) {
            endStar()
        } else {
            throw error(previous(), message)
        }
    }

    func error(token: Token, message: String): ParseError {
        reporter.error(token, message)
        ParseError()
    }

    func consume(kind: TokenKind, message: String): Token {
        if (check(kind)) { return advance() }

        throw error(peek(), message)
    }
}