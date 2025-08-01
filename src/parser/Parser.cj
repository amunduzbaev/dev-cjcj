package cjcj.parser

import cjcj.ast.*

import std.collection.ArrayList
import std.convert.*

// Temporary imports to not have compilation errors.
import std.ast.Token
import std.ast.TokenKind

/* Current Grammar
program        → declaration* EOF ;

declaration    → varDecl
               | statement ;

varDecl        → ( "var" | "let" ) IDENTIFIER ( "=" expression )? ( ";" | "\n" ) ;

statement      → exprStmt
               | printStmt ;

exprStmt       → expression ( ";" | "\n" ) ;

printStmt      → "print" expression ( ";" | "\n" ) ;

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

    private func expression(): Expr {
        equality()
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

    private func statement(): ?Node {
        // if (matches(TokenKind.PRINT)) {
        //     return printStatement()
        // }
        return expressionStatement()
    }

    // private func printStatement(): Statement {
    //     let value: Expr = expression()
    //     consume(TokenKind.SEMI, "Expect ';' after value.")
    //     return Print(value)
    // }

    private func varDeclaration(): VarDecl {
        let keyword: Token = previous()
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect variable name.")
        var initializer: ?Expr = None
        if (matches(TokenKind.ASSIGN)) {
            initializer = Some(expression())
        }
    
        VarDecl(keyword, name, initializer)
    }

    private func expressionStatement(): ?Node {
        let expr: Expr = expression()
        if (!isAtEnd() && !matches(TokenKind.SEMI, TokenKind.NL)) {
            consume(TokenKind.ILLEGAL, "Expect ';' after expression.")
        }
        return expr
    }

    private func equality(): Expr {
        var expr: Expr = comparison()

        while (matches(TokenKind.NOTEQ, TokenKind.EQUAL)) {
            let oper: Token = previous()
            let right: Expr = comparison()
            expr = Binary(expr, oper, right)
        }
        expr
    }

    private func comparison(): Expr {
        var expr: Expr = term()

        while (matches(TokenKind.GT, TokenKind.GE, TokenKind.LT, TokenKind.LE)) {
            let oper: Token = previous()
            let right: Expr = term()
            expr = Binary(expr, oper, right)
        }
        expr
    }

    private func term(): Expr {
        var expr: Expr = factor()

        while (matches(TokenKind.ADD, TokenKind.SUB)) {
            let oper: Token = previous()
            let right: Expr = factor()
            expr = Binary(expr, oper, right)
        }
        expr
    }

    private func factor(): Expr {
        var expr: Expr = unary()

        while (matches(TokenKind.MUL, TokenKind.DIV)) {
            let oper: Token = previous()
            let right: Expr = unary()
            expr = Binary(expr, oper, right)
        }
        expr
    }

    private func unary(): Expr {
        if (matches(TokenKind.NOT, TokenKind.SUB)) {
            let oper: Token = previous()
            let right: Expr = unary()
            return Unary(oper, right)
        }

        primary()
    }

    private func primary(): Expr {
        if (matches(TokenKind.BOOL_LITERAL)) { return Literal(Some(Bool.parse(previous().value))) }
        if (matches(TokenKind.INTEGER_LITERAL, TokenKind.STRING_LITERAL)) { return Literal(previous().value) }
        if (matches(TokenKind.LPAREN)) {
            let expr: Expr = expression()
            consume(TokenKind.RPAREN, "Expect ')' after expression.")
            return Grouping(expr)
        }
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
                peek().kind == TokenKind.FOR ||
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

    private func previous() {
        tokens.get(current - 1).getOrThrow()
    }
}
