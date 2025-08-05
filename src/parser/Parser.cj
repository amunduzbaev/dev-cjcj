package cjcj.parser

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.collection.ArrayList
import std.convert.*


/* Current Grammar
program        → declaration* EOF ;

declaration    → varDecl
               | statement ;

varDecl        → ( "var" | "let" ) IDENTIFIER ( "=" expression )? ( ";" | "\n" ) ;

statement      → exprStmt
               | ifStmt ;

exprStmt       → expression ( ";" | "\n" ) ;

expression     → assignment ;

assignment     → IDENTIFIER "=" assignment
               | equality ;

equality       → comparison ( ( "!=" | "==" ) comparison )* ;

comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;

term           → factor ( ( "-" | "+" ) factor )* ;

factor         → unary ( ( "/" | "*" ) unary )* ;

unary          → ( "!" | "-" ) unary
               | primary ;

primary        → "true" | "false" |
               | NUMBER | STRING
               | "(" expression ")"
               | IDENTIFIER ;
*/

private class ParseError <: Exception { }

public class Parser {
    private let tokens: Array<Token>
    private let reporter: Reporter
    private var current: Int64 = 0


    public Parser(tokens: Array<Token>, reporter: Reporter) {
        this.tokens = tokens
        this.reporter = reporter
    }

    public func parse(): ?Array<Node> {
        let statements: ArrayList<Node> = ArrayList()
        try {
            while (!isAtEnd()) {
                statements.add(declaration().getOrThrow())
            }
            return Some(statements.toArray())
        } catch (error: ParseError) {
            return None
        }
    }

    private func expression(): Node {
        assignment()
    }

    // Right associative
    private func assignment(): Node {
        let expr: Node = equality()

        if (matches(TokenKind.ASSIGN)) {
            let equals: Token = previous()
            let value: Expr = (assignment() as Expr).getOrThrow()

            if (expr is VarPattern) {
                let name: Token = (expr as VarPattern).getOrThrow().identifier
                return Assign(name, value)
            }

            error(equals, "Invalid assignment target.")
        }

        expr
    }

    private func declaration(): ?Node {
        try {
            if (matches(TokenKind.LET, TokenKind.VAR)) {
                return varDeclaration()
            }
            return statement()
        } catch (error: ParseError) {
            synchronize()
            return None
        }
    }

    private func statement(): Node {
        if (matches(TokenKind.IF)) {
            return ifExpr()
        }
        if (matches(TokenKind.LCURL)) {
            return Block(block())
        }
        return expressionStatement()
    }

    private func ifExpr(): Expr {
        consume(TokenKind.LPAREN, "Expect '(' before condition.")
        let condition: Node = expression()
        consume(TokenKind.RPAREN, "Expect ')' after condition.")
        skipNL()
        consume(TokenKind.LCURL, "Expect '{' before if block.")
        let ifBlock: Block = Block(block())
        
        var elseBranch: ?Expr = None
        if (matches(TokenKind.ELSE)) {
            elseBranch = statement() as Expr
        }
        IfExpr((condition as Expr).getOrThrow(), ifBlock, elseBranch)
    }

    private func block(): Array<Node> {
        let statements = ArrayList<Node>()
        skipNL()
        while (!check(TokenKind.RCURL) && !isAtEnd()) {
            statements.add(declaration().getOrThrow())
        }
        consume(TokenKind.RCURL, "Expect '}' after block.")
        skipNL()
        statements.toArray()
    }


    private func varDeclaration(): VarDecl {
        let keyword: Token = previous()
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect variable name.")
        var initializer: ?Expr = None
        if (matches(TokenKind.ASSIGN)) {
            initializer = expression() as Expr
        }
        if (!isAtEnd() && !matches(TokenKind.SEMI, TokenKind.NL)) {
            consume(TokenKind.SEMI, "Expect ';' or new line after variable declaration.")
        }
        VarDecl(keyword, name, initializer)
    }

    private func expressionStatement(): Node {
        let expr: Node = expression()
        if (!isAtEnd() && !matches(TokenKind.SEMI, TokenKind.NL)) {
            consume(TokenKind.SEMI, "Expect ';' or new line after expression.")
        }
        return expr
    }

    private func equality(): Node {
        var expr: Node = comparison()

        while (matches(TokenKind.NOTEQ, TokenKind.EQUAL)) {
            let oper: Token = previous()
            let right: Expr = (comparison() as Expr).getOrThrow()
            expr = Binary((expr as Expr).getOrThrow(), oper, right)
        }
        expr
    }

    private func comparison(): Node {
        var expr: Node = term()

        while (matches(TokenKind.GT, TokenKind.GE, TokenKind.LT, TokenKind.LE)) {
            let oper: Token = previous()
            let right: Expr = (term() as Expr).getOrThrow()
            expr = Binary((expr as Expr).getOrThrow(), oper, right)
        }
        expr
    }

    private func term(): Node {
        var expr: Node = factor()

        while (matches(TokenKind.ADD, TokenKind.SUB)) {
            let oper: Token = previous()
            let right: Node = factor()
            expr = Binary(expr, oper, right)
        }
        expr
    }

    private func factor(): Node {
        var expr: Node = unary()

        while (matches(TokenKind.MUL, TokenKind.DIV)) {
            let oper: Token = previous()
            let right: Expr = (unary() as Expr).getOrThrow()
            expr = Binary((expr as Expr).getOrThrow(), oper, right)
        }
        expr
    }

    private func unary(): Node {
        if (matches(TokenKind.NOT, TokenKind.SUB)) {
            let oper: Token = previous()
            let right: Expr = (unary() as Expr).getOrThrow()
            return Unary(oper, right)
        }

        primary()
    }

    private func primary(): Node {
        if (matches(TokenKind.BOOL_LITERAL)) { return Literal(Some(Bool.parse(previous().value))) }
        if (matches(TokenKind.INTEGER_LITERAL, TokenKind.STRING_LITERAL)) { return Literal(previous().value) }
        if (matches(TokenKind.LPAREN)) {
            let expr: Node = expression()
            consume(TokenKind.RPAREN, "Expect ')' after expression.")
            return Grouping(expr)
        }
        if (matches(TokenKind.IDENTIFIER)) { return VarPattern(previous()) }     
        // if (matches(TokenKind.IDENTIFIER)) { return Variable(previous()) }         
        throw error(peek(), "Expect expression.")
    }

    private func consume(kind: TokenKind, message: String): Token {
        if (check(kind)) { return advance() }

        throw error(peek(), message)
    }

    private func error(token: Token, message: String): ParseError {
        reporter.error(token, message)
        ParseError()
    }

    /**
    * When we find an error we don't want to break everything and stop parsing.
    * So we synchronize, we discard tokens utinl we find a statement boundary.
    */
    private func synchronize(): Unit {
        advance()

        while (!isAtEnd()) {
            // Finished a statement
            if (previous().kind == TokenKind.SEMI) { return }

            if (peek().kind == TokenKind.CLASS ||
                peek().kind == TokenKind.FUNC ||
                peek().kind == TokenKind.VAR ||
                peek().kind == TokenKind.IF ||
                peek().kind == TokenKind.WHILE ||
                peek().kind == TokenKind.RETURN
            ) {
                return
            }
            advance()
        }
    }

    private func matches(types: Array<TokenKind>): Bool {
        for (kind in types) {
            if (check(kind)) {
                advance()
                return true
            }
        }
        return false
    }

    private func check(kind: TokenKind): Bool {
        if (isAtEnd()) {
            return false
        }
        peek().kind == kind
    }

    private func advance(): Token {
        if (!isAtEnd()) {
            current++
        }
        previous()
    }

    private func isAtEnd(): Bool {
        peek().kind == TokenKind.END
    }

    private func peek(): Token {
        tokens.get(current).getOrThrow()
    }

    private func previous(): Token {
        tokens.get(current - 1).getOrThrow()
    }

    private func skipNL(): Unit {
        while(check(TokenKind.NL)) {
            advance()
        }
    }
}
