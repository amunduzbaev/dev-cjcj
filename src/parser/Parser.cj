package cjcj.parser

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.scanner.TokenKindHelper

import std.collection.ArrayList
import std.convert.Parsable

/* Current Grammar
program        → (declaration | classDecl | structDecl)* EOF ;

declaration    → varDecl
               | funcDecl
               | statement ;

classDecl      → "class" IDENTIFIER block ;

structDecl     → "struct" IDENTIFIER block ;

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

public class NodeIdManager {
    private static var count: UInt64 = 0

    public static func nextId(): NodeId {
        let id = NodeId(count)
        count++
        id
    }
}

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
            skipNL()
            while (!isAtEnd()) {
                let modifiers: ArrayList<Modifier> = modifiers()
                // We're calling class and other custom declarations here
                // because you cannot have a class inside a class.
                if (matches(TokenKind.CLASS)) {
                    nodes.add(classDeclaration().getOrThrow())
                } else if (matches(TokenKind.STRUCT)) {
                    nodes.add(structDeclaration(modifiers))
                } else {
                    nodes.add(node(modifiers))
                }
                skipNL()
            }
            return nodes.toArray()
        } catch (error: ParseError) {
            return None
        }
    }

    private func node(modifiers: ArrayList<Modifier>): Node {
        if (let Some(decl) <- declaration(modifiers)) {
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
            let value: Expr = assignment()
            return Assign(NodeIdManager.nextId(), expr, value)
        }

        expr
    }

    private func or(): Expr {
        var expr: Expr = and()
        while (matches(TokenKind.OR)) {
            let oper: Token = previous()
            let right: Expr = and()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func and(): Expr {
        var expr: Expr = equality()
        while (matches(TokenKind.AND)) {
            let oper: Token = previous()
            let right: Expr = equality()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func declaration(modifiers: ArrayList<Modifier>): ?Decl {
        skipNL()
        try {
            if (matches(TokenKind.LET, TokenKind.VAR)) {
                return varDeclaration(modifiers)
            }
            if (matches(TokenKind.FUNC)) {
                return function(modifiers)
            }
            if (matches(TokenKind.INIT)) {
                return initialiser(modifiers)
            }
        } catch (error: ParseError) {
            synchronize()
        }
        None
    }

    private func initialiser(modifiers:ArrayList<Modifier>): InitDecl {
        let parameters: ArrayList<FuncParam> = ArrayList()

        let keyword: Token = previous()

        if (!matches(TokenKind.UNIT_LITERAL)) {
            consume(TokenKind.LPAREN, "Expect '(' after initialiser " + " name.")
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
        consume(TokenKind.LCURL, "Expect '{' before initialiser" + " body.")
        let body: Body = Body(NodeIdManager.nextId(), body())
        var declType: ?TypeNode = None

        InitDecl(NodeIdManager.nextId(), keyword, body, modifiers, parameters)

        
    }


    private func function(modifiers: ArrayList<Modifier>): FuncDecl {
        let keyword: Token = previous()
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect function name.")
        let parameters: ArrayList<FuncParam> = ArrayList()
        if (!matches(TokenKind.UNIT_LITERAL)) {
            consume(TokenKind.LPAREN, "Expect '(' after function " + " name.")
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
                declType = PrimitiveType(NodeIdManager.nextId(),
                                            name, advance())
            } catch (_: IllegalArgumentException) {
            }
        }
        consume(TokenKind.LCURL, "Expect '{' before function body.")
        let block: Block = Block(NodeIdManager.nextId(), block())
        FuncDecl(NodeIdManager.nextId(),
                keyword, name, block, modifiers, parameters, declType)

        FuncDecl(NodeIdManager.nextId(), keyword, name, block, modifiers, parameters, declType)
        
    }

    private func funcParameter(): FuncParam {
        let parameterName = consume(TokenKind.IDENTIFIER,
            "Expect parameter name")
        consume(TokenKind.COLON, "Expect ':' after parameter name")
        let keyword = advance()
        // TODO: Add check for type category.
        FuncParam(NodeIdManager.nextId(),
            PrimitiveType(NodeIdManager.nextId(), parameterName, keyword))
    }

    private func classDeclaration(): ?ClassDecl {
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect class name.")
        consume(TokenKind.LCURL, "Expect '{' before class body.")
        let body: Body = Body(NodeIdManager.nextId(), body())

        ClassDecl(NodeIdManager.nextId(), name, body)

    }

    private func structDeclaration(modifiers: ArrayList<Modifier>): StructDecl {
        let keyword: Token = previous()
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect struct name.")
        consume(TokenKind.LCURL, "Expect '{' before struct body.")

        let body: Body = Body(NodeIdManager.nextId(), body())
        StructDecl(NodeIdManager.nextId(), keyword, name, modifiers, body)

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
            return Block(NodeIdManager.nextId(), block())
        }
        return expressionStatement()
    }

    private func returnExpr(): Expr {
        let keyword: Token = previous()
        var value: Expr = Expr(NodeIdManager.nextId())

        if (!check(TokenKind.SEMI) && !check(TokenKind.NL)) {
            value = expression()
        }
        if (!isAtEnd() && !matches(TokenKind.SEMI, TokenKind.NL)) {
            consume(TokenKind.SEMI,
                "Expect ';' or new line after return statement.")
        }

        ReturnExpr(NodeIdManager.nextId(), value, keyword)
    }

    private func ifExpr(): Expr {
        consume(TokenKind.LPAREN, "Expect '(' before condition.")
        let condition: Expr = expression()
        consume(TokenKind.RPAREN, "Expect ')' after condition.")
        
        consume(TokenKind.LCURL, "Expect '{' before if block.")
        let ifBlock: Block = Block(NodeIdManager.nextId(), block())
        
        var elseBranch: ?Expr = None
        if (matches(TokenKind.ELSE)) {
            elseBranch = statement()
        }
        IfExpr(NodeIdManager.nextId(), condition, ifBlock, elseBranch)
    }

    private func whileExpr(): Expr {
        consume(TokenKind.LPAREN, "Expect '(' before condition.")
        let condition: Expr = expression()
        consume(TokenKind.RPAREN, "Expect ')' after condition.")
        consume(TokenKind.LCURL, "Expect '{' before if block.")
        let block: Block = Block(NodeIdManager.nextId(), block())
        WhileExpr(NodeIdManager.nextId(), condition, block)
    }

    private func block(): Array<Node> {
        let nodes = ArrayList<Node>()
        
        skipNL()
        while (!check(TokenKind.RCURL) && !isAtEnd()) {
            try {nodes.add(node(modifiers()))
            skipNL()
            } catch (error: ParseError) {
            synchronize()
            }
        }
        consume(TokenKind.RCURL, "Expect '}' after block.")
        
        nodes.toArray()
    }


    private func body(): Array<Decl> {
        let nodes = ArrayList<Decl>()
        
        while (!check(TokenKind.RCURL) && !isAtEnd()) {
            try {
                skipNL()
                if (let Some(a) <- declaration(modifiers())) {
                    nodes.add(a)
                    }
                else {
                    throw error(peek(),"Found non-declaration in Struct or Class declaration")
                }
                

            } catch (error: ParseError) {
                synchronize()
            }
        }
        consume(TokenKind.RCURL, "Expect '}' after body.")
        
        nodes.toArray()
    }


    private func varDeclaration(modifiers: ArrayList<Modifier>): VarDecl {
        let keyword: Token = previous()
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect variable name.")

        var declType: ?TypeNode = None
        if (matches(TokenKind.COLON)) {
            try {
                declType = PrimitiveType(
                    NodeIdManager.nextId(), name, advance()
                )
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
        VarDecl(NodeIdManager.nextId(),
            keyword, name, initializer, modifiers, declType)
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
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        expr
    }

    private func comparison(): Expr {
        var expr: Expr = term()
        while (matches(TokenKind.GT, TokenKind.GE,
                TokenKind.LT, TokenKind.LE)) {
            let oper: Token = previous()
            let right: Expr = term()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        expr
    }

    private func term(): Expr {
        var expr: Expr = factor()
        while (matches(TokenKind.ADD, TokenKind.SUB)) {
            let oper: Token = previous()
            let right: Expr = factor()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        expr
    }

    private func factor(): Expr {
        var expr: Expr = unary()
        while (matches(TokenKind.MUL, TokenKind.DIV)) {
            let oper: Token = previous()
            let right: Expr = unary()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        expr
    }

    private func unary(): Expr {
        if (matches(TokenKind.NOT, TokenKind.SUB)) {
            let oper: Token = previous()
            let right: Expr = unary()
            return Unary(NodeIdManager.nextId(), oper, right)
        }
        call()
    }

    private func finishCall(callee: Expr): Expr {
        let arguments: ArrayList<Argument> = ArrayList()
        if (matches(TokenKind.LPAREN)) {
            if (!check(TokenKind.RPAREN)) {
                do {
                    arguments.add(Argument(NodeIdManager.nextId(),
                                            expression()))
                } while (matches(TokenKind.COMMA))
            }

            consume(TokenKind.RPAREN, "Expect ')' after agruments.")
        }
        else {
            consume(TokenKind.UNIT_LITERAL,
                "Expect '()' if no parameters are passed")
        }
        CallExpr(NodeIdManager.nextId(), callee, arguments)
    }

    private func call(): Expr {
        var expr: Expr = primary()
        while (true) {
            if (check(TokenKind.LPAREN) || check(TokenKind.UNIT_LITERAL)) {
                expr = finishCall(expr)
            } else if (matches(TokenKind.DOT)) {
                let name: Token = consume(TokenKind.IDENTIFIER,
                    "Expected property name after '.'.")
                expr = MemberAccess(NodeIdManager.nextId(), expr, name)
                
                if (matches(TokenKind.COLON)) {
                    
                }
            } else {
                break
            }
        }
        expr
    }

    private func primary(): Expr {
        if (matches(TokenKind.BOOL_LITERAL)) {
            return Literal(NodeIdManager.nextId(), Bool.parse(previous().value))
        }
        if (matches(TokenKind.INTEGER_LITERAL, TokenKind.STRING_LITERAL)) {
            return Literal(NodeIdManager.nextId(), previous().value)
        }
        if (matches(TokenKind.LPAREN)) {
            let expr: Expr = expression()
            consume(TokenKind.RPAREN, "Expect ')' after expression.")
            return Grouping(NodeIdManager.nextId(), expr)
        }
        if (matches(TokenKind.IDENTIFIER)) {
            return RefExpr(NodeIdManager.nextId(), previous())
        }
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
            if (previous().kind == TokenKind.SEMI || previous().kind == TokenKind.NL) { return }

            if (peek().kind == TokenKind.CLASS ||
                peek().kind == TokenKind.FUNC ||
                peek().kind == TokenKind.VAR ||
                peek().kind == TokenKind.IF ||
                peek().kind == TokenKind.WHILE ||
                peek().kind == TokenKind.RETURN ||
                peek().kind == TokenKind.STRUCT
            ) {
                return
            }
            advance()
        }
    }

    private func modifiers(): ArrayList<Modifier> {
        let modifiers: ArrayList<Modifier> = ArrayList()
        while (matches(TokenKindHelper.MODIFIERS_TOKEN_KIND)) {
            modifiers.add(Modifier(NodeIdManager.nextId(), previous()))
        }
        modifiers
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

    private func checkNext(kind: TokenKind): Bool {  //THINK ABOUT EOF, WHAT TO DO IF WE'RE AT THE END OF THE ARRAY
        if (isAtEnd()) {
            return false
        }
        peekNext().kind == kind
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

    private func peekNext(): Token {
        tokens[current + 1]
    }
    
    private func previous(): Token {
        tokens[current - 1]
    }

    private func skipNL(): Unit {
        if (check(TokenKind.NL)) {
            advance()
        }
    }
}
