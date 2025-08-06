package cjcj.parser

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.collection.ArrayList
import std.convert.Parsable

/* Current Grammar
program        → (declaration | classDecl)* EOF ;

declaration    → varDecl
               | funcDecl
               | statement ;

classDecl      → "class" IDENTIFIER block ;

varDecl        → ( "var" | "let" ) IDENTIFIER ( "=" expression )? ( ";" | "\n");

funDecl        → "func" function ;

function       → IDENTIFIER "(" parameters? ")" block ;

parameters     → IDENTIFIER ( "," IDENTIFIER )* ;

statement      → exprStmt
               | ifStmt
               | whileStmt
               | returnStmt
               | block;

block          → "{" declaration* "}" ;

returnStmt     → "return" expression? ";" ;

ifStmt         → "if" "(" expression ")" statement
               ( "else" statement )? ;

whileStmt      → "while" "(" expression ")" statement ;

exprStmt       → expression ( ";" | "\n" ) ;

expression     → assignment ;

assignment     → ( call "." )? IDENTIFIER "=" assignment
               | logic_or ;

logic_or       → logic_and ( "or" logic_and )* ;

logic_and      → equality ( "and" equality )* ;

equality       → comparison ( ( "!=" | "==" ) comparison )* ;

comparison     → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;

term           → factor ( ( "-" | "+" ) factor )* ;

factor         → unary ( ( "/" | "*" ) unary )* ;

unary          → ( "!" | "-" ) unary | call;

call           → primary ( "(" arguments? ")" | "." IDENTIFIER )* ;

arguments      → expression ( "," expression )* ;

primary        → "true" | "false" |
               | NUMBER | STRING
               | "(" expression ")"
               | IDENTIFIER ;
*/

private class ParseError <: Exception { }

public class Parser {
    private static let MAX_PARAM_NUMBER = 255
    private let tokens: Array<Token>
    private let reporter: Reporter
    private var current: Int64 = 0


    public Parser(tokens: Array<Token>, reporter: Reporter) {
        this.tokens = tokens
        this.reporter = reporter
    }

    public func parse(): ?Array<Node> {
        let nodes: ArrayList<Node> = ArrayList()
        try {
            while (!isAtEnd()) {
                if (matches(TokenKind.CLASS)) {
                    nodes.add(classDeclaration().getOrThrow())
                }else{
                    nodes.add(node())
                }
            }
            return nodes.toArray()
        } catch (error: ParseError) {
            return None
        }
    }

    private func node(): Node {
        if (let Some(decl) <- declaration()) {
            return decl
        }
        return statement()
    }

    private func expression(): Expr {
        assignment()
    }

    // Right associative
    private func assignment(): Expr {
        let expr: Expr = or()

        if (matches(TokenKind.ASSIGN)) {
            let equals: Token = previous()
            let value: Expr = assignment()

            if (expr is RefExpr) {
                let name: Token = (expr as RefExpr).getOrThrow().identifier
                return Assign(name, value)
            }
            throw error(equals, "Invalid assignment target.")
        }

        expr
    }

    private func or(): Expr {
        var expr: Expr = and()
        while (matches(TokenKind.OR)) {
            let oper: Token = previous()
            let right: Expr = and()
            expr = Logical(expr, oper, right)
        }
        return expr
    }

    private func and(): Expr {
        var expr: Expr = equality()
        while (matches(TokenKind.AND)) {
            let oper: Token = previous()
            let right: Expr = equality()
            expr = Logical(expr, oper, right)
        }
        return expr
    }

    private func declaration(): ?Decl {
        skipNL()
        try {
            if (matches(TokenKind.LET, TokenKind.VAR)) {
                return varDeclaration()
            }
            if (matches(TokenKind.FUNC)) {
                return function("function")
            }
        } catch (error: ParseError) {
            synchronize()
        }
        None
    }

    private func function(kind: String): FuncDecl {
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect " + kind +
                                    " name.")
        let parameters: ArrayList<FuncParam> = ArrayList()
        if (!matches(TokenKind.UNIT_LITERAL)) {
            consume(TokenKind.LPAREN, "Expect '(' after " + kind + " name.")
            if (!check(TokenKind.RPAREN)) {
                do {
                    if (parameters.size >= MAX_PARAM_NUMBER) {
                        throw error(peek(), "Can't have more than " +
                            MAX_PARAM_NUMBER.toString() + " parameters.")
                    }

                    parameters.add(funcParameter())
                } while(matches(TokenKind.COMMA))
            }
            consume(TokenKind.RPAREN, "Expect ') after parameters.")
        }
        var declType: ?TypeNode = None
        if (matches(TokenKind.COLON)) {
            try {
                declType = PrimitiveType(name, advance())
            } catch (_: IllegalArgumentException) {
            }
        }
        consume(TokenKind.LCURL, "Expect '{' before " + kind + " body.")
        let block: Block = Block(block())
        FuncDecl(name, block, parameters, declType)
    }

    private func funcParameter(): FuncParam {
        let parameterName = consume(TokenKind.IDENTIFIER,
            "Expect parameter name")
        consume(TokenKind.COLON, "Expect ':' after parameter name")
        let keyword = advance()
        // TODO: Add check for type category.
        FuncParam(PrimitiveType(parameterName, keyword))
    }

    private func classDeclaration(): ?ClassDecl {
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect class name.")
        consume(TokenKind.LCURL, "Expect '{' before class body.")
        let block: Block = Block(block())

        ClassDecl(name, block)

    }

    private func statement(): Expr {
        skipNL()
        if (matches(TokenKind.IF)) {
            return ifExpr()
        }
        if (matches(TokenKind.WHILE)) {
            return whileExpr()
        }
        if (matches(TokenKind.RETURN)) {
            return returnExpr()
        }
        if (matches(TokenKind.LCURL)) {
            return Block(block())
        }
        return expressionStatement()
    }

    private func returnExpr(): Expr {
        let keyword: Token = previous()
        var value: Expr = Expr()

        if (!check(TokenKind.SEMI) && !check(TokenKind.NL)) {
            value = expression()
        }
        if (!isAtEnd() && !matches(TokenKind.SEMI, TokenKind.NL)) {
            consume(TokenKind.SEMI,
                "Expect ';' or new line after return statement.")
        }

        ReturnExpr(value, keyword)
    }

    private func ifExpr(): Expr {
        consume(TokenKind.LPAREN, "Expect '(' before condition.")
        let condition: Expr = expression()
        consume(TokenKind.RPAREN, "Expect ')' after condition.")
        
        consume(TokenKind.LCURL, "Expect '{' before if block.")
        let ifBlock: Block = Block(block())
        
        var elseBranch: ?Expr = None
        if (matches(TokenKind.ELSE)) {
            elseBranch = statement()
        }
        IfExpr(condition, ifBlock, elseBranch)
    }

    private func whileExpr(): Expr {
        consume(TokenKind.LPAREN, "Expect '(' before condition.")
        let condition: Expr = expression()
        consume(TokenKind.RPAREN, "Expect ')' after condition.")
        consume(TokenKind.LCURL, "Expect '{' before if block.")
        let block: Block = Block(block())
        WhileExpr(condition, block)
    }

    private func block(): Array<Node> {
        let nodes = ArrayList<Node>()
        
        while (!check(TokenKind.RCURL) && !isAtEnd()) {
            nodes.add(node())
        }
        consume(TokenKind.RCURL, "Expect '}' after block.")
        
        nodes.toArray()
    }


    private func varDeclaration(): VarDecl {
        let keyword: Token = previous()
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect variable name.")

        var declType: ?TypeNode = None
        if (matches(TokenKind.COLON)) {
            try {
                declType = PrimitiveType(name, advance())
            } catch (_: IllegalArgumentException) {
                throw error(peek(), "Expected primitive type.")
            }
        }

        var initializer: ?Expr = None
        if (matches(TokenKind.ASSIGN)) {
            initializer = expression()
        }
        if (!isAtEnd() && !matches(TokenKind.SEMI, TokenKind.NL)) {
            consume(TokenKind.SEMI,
                "Expect ';' or new line after variable declaration.")
        }
        VarDecl(keyword, name, initializer, declType)
    }

    private func expressionStatement(): Expr {
        let expr: Expr = expression()
        if (!isAtEnd() && !matches(TokenKind.SEMI, TokenKind.NL)) {
            consume(TokenKind.SEMI, "Expect ';' or new line after expression.")
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
        while (matches(TokenKind.GT, TokenKind.GE,
                TokenKind.LT, TokenKind.LE)) {
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
        call()
    }

    private func finishCall(callee: Expr): Expr {
        let arguments: ArrayList<Argument> = ArrayList()
        if (matches(TokenKind.LPAREN)) {
            if (!check(TokenKind.RPAREN)) {
                do {
                    arguments.add(Argument(expression()))
                } while (matches(TokenKind.COMMA))
            }

            consume(TokenKind.RPAREN, "Expect ')' after agruments.")
        }
        else {
            consume(TokenKind.UNIT_LITERAL,
                "Expect '()' if no parameters are passed")
        }
        CallExpr(callee, arguments)
    }

    private func call(): Expr {
        var expr: Expr = primary()
        while (true) {
            if (check(TokenKind.LPAREN) || check(TokenKind.UNIT_LITERAL)) {
                expr = finishCall(expr)
            } else {
                break
            }
        }
        expr
    }

    private func primary(): Expr {
        skipNL()
        if (matches(TokenKind.BOOL_LITERAL)) {
            return Literal(Bool.parse(previous().value))
        }
        if (matches(TokenKind.INTEGER_LITERAL, TokenKind.STRING_LITERAL)) {
            return Literal(previous().value)
        }
        if (matches(TokenKind.LPAREN)) {
            let expr: Expr = expression()
            consume(TokenKind.RPAREN, "Expect ')' after expression.")
            return Grouping(expr)
        }
        if (matches(TokenKind.IDENTIFIER)) { return RefExpr(previous()) }
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
    * So we synchronize, we discard tokens until we find a statement boundary.
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
        tokens[current]
    }

    private func previous(): Token {
        tokens[current - 1]
    }

    private func skipNL(): Unit {
        while(check(TokenKind.NL)) {
            advance()
        }
    }
}
