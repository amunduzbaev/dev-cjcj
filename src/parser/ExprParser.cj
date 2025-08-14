package cjcj.parser

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.scanner.TokenKindHelper

import std.collection.ArrayList

internal class ExprParser <: DeclParser {
    public ExprParser(tokens: Array<Token>) {
        super(tokens)
    }

    public func expression(): Expr {
        assignmentExpression()
    }

    private func leftValueExpression(): ?Expr {
        return leftValueExpressionWithoutWildCard()
    }

    private func leftValueExpressionWithoutWildCard(): ?Expr {
        return identifier()
    }

    private func callSuffix(callee: Expr): Expr {
        let arguments: ArrayList<Argument> = ArrayList()
        if (matches(TokenKind.LPAREN)) {
            skipNL()
            if (!check(TokenKind.RPAREN)) {
                do {
                    skipNL()
                    arguments.add(Argument(NodeIdManager.nextId(),
                                            expression()))
                    skipNL()
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

    private func assignmentExpression(): Expr {
        let tmp: Int64 = current
        if (let Some(value) <- leftValueExpression()) {
            if (matches(TokenKindHelper.ASSIGNMENT_OPERATOR)) {
                return Assign(NodeIdManager.nextId(), value, logicConjunctionExpression())
            }
        }
        // Going back if I didn't find an assignment.
        // TODO: Think about a better solution.
        current = tmp
        logicDisjunctionExpression()
    }

    private func identifier(): ?Expr {
        if (matches(TokenKind.IDENTIFIER)) {
            return RefExpr(NodeIdManager.nextId(), previous())
        }
        None
    }

    private func logicDisjunctionExpression(): Expr {
        var expr: Expr = logicConjunctionExpression()
        while (matches(TokenKind.OR)) {
            let oper: Token = previous()
            skipNL()
            let right: Expr = logicConjunctionExpression()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func logicConjunctionExpression(): Expr {
        var expr: Expr = bitwiseDisjunctionExpression()
        while (skipNLCompare(TokenKind.AND)) {
            let oper: Token = previous()
            skipNL()
            let right: Expr = bitwiseDisjunctionExpression()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func bitwiseDisjunctionExpression(): Expr {
        var expr: Expr = bitwiseConjunctionExpression()
        while (skipNLCompare(TokenKind.BITOR)) {
            let oper: Token = previous()
            skipNL()
            let right: Expr = bitwiseConjunctionExpression()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func bitwiseConjunctionExpression(): Expr {
        var expr: Expr = equalityComparisonExpression()
        while (skipNLCompare(TokenKind.BITAND)) {
            let oper: Token = previous()
            skipNL()
            let right: Expr = equalityComparisonExpression()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func equalityComparisonExpression(): Expr {
        var expr: Expr = comparisonOrTypeExpression()
        while (skipNLCompare(TokenKindHelper.EQUALITY_OPERATOR)) {
            let oper: Token = previous()
            skipNL()
            let right: Expr = comparisonOrTypeExpression()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func comparisonOrTypeExpression(): Expr {
        var expr: Expr = additiveExpression()
        while (skipNLCompare(TokenKindHelper.COMPARISON_OPERATOR)) {
            let oper: Token = previous()
            skipNL()
            let right: Expr = additiveExpression()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func additiveExpression(): Expr {
        var expr: Expr = multiplicativeExpression()
        while (skipNLCompare(TokenKindHelper.ADDITIVE_OPERATOR)) {
            let oper: Token = previous()
            skipNL()
            let right: Expr = multiplicativeExpression()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func multiplicativeExpression(): Expr {
        var expr: Expr = exponentExpression()
        while (skipNLCompare(TokenKindHelper.MULTIPLICATIVE_OPERATOR)) {
            let oper: Token = previous()
            skipNL()
            let right: Expr = exponentExpression()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        expr
    }

    private func exponentExpression(): Expr {
        var expr: Expr = prefixUnaryExpression()
        while (skipNLCompare(TokenKindHelper.EXPONENT_OPERATOR)) {
            let oper: Token = previous()
            skipNL()
            let right: Expr = prefixUnaryExpression()
            expr = Binary(NodeIdManager.nextId(), expr, oper, right)
        }
        expr
    }

    private func prefixUnaryExpression(): Expr {
        // TODO: now an expression like --5 is ok but in the future
        // we will add the inc and dec operators that will be after this so that
        // the problem will be solved.
        // TODO: Think about how to handle multiple operators (!!!!!!5 is fine).
        if (matches(TokenKindHelper.PREFIX_UNARY_OPERATOR)) {
            let oper: Token = previous()
            let right: Expr = postfixExpression()
            return Unary(NodeIdManager.nextId(), oper, right)
        }
        postfixExpression()
    }

    private func postfixExpression(): Expr {
        var expr: Expr = atomicExpression()
        var changed = true
        while (changed) {
            changed = false
            while (check(TokenKind.LPAREN) || check(TokenKind.UNIT_LITERAL)) {
                expr = callSuffix(expr)
                changed = true
            }
        }
        expr
    }

    private func atomicExpression(): Expr {
        if (matches(TokenKindHelper.LITERAL_CONSTANT)) {
            return Literal(NodeIdManager.nextId(), previous().value)
        }
        if (check(TokenKind.IF)) {
            return ifExpression()
        }
        if (let Some(loop) <- loopExpression()) {
            return loop
        }
        if (let Some(jump) <- jumpExpression()) {
            return jump
        }
        if (let Some(i) <- identifier()) {
            return i
        }
        if (matches(TokenKind.LPAREN)) {
            skipNL()
            let expr: Expr = expression()
            skipNL()
            consume(TokenKind.RPAREN, "Expected ')' after expression.")
            return Grouping(NodeIdManager.nextId(), expr)
        }
        throw error(peek(), "Expect expression.")
    }

    private func returnExpr(): Expr {
        consume(TokenKind.RETURN, "Expected 'return' for return expression")
        let keyword: Token = previous()
        let tmp: Int64 = current
        skipNL()
        var value: ?Expr = None
        try {
            value = expression()
        } catch (_) { current = tmp }
        ReturnExpr(NodeIdManager.nextId(), value, keyword)
    }

    private func ifExpression(): Expr {
        consume(TokenKind.IF, "Expected 'if' for if expression.")
        skipNL()
        consume(TokenKind.LPAREN, "Expect '(' before condition.")
        skipNL()
        let condition: Expr = expression()
        skipNL()
        consume(TokenKind.RPAREN, "Expect ')' after condition.")
        skipNL()
        let ifBlock: Block = block()
        
        skipNL()
        var elseBranch: ?Expr = None
        if (matches(TokenKind.ELSE)) {
            skipNL()
            if (check(TokenKind.IF)) {
                elseBranch = ifExpression()
            } else {
                elseBranch = block()
            }
        }
        IfExpr(NodeIdManager.nextId(), condition, ifBlock, elseBranch)
    }

    private func whileExpr(): Expr {
        consume(TokenKind.WHILE, "Expected 'while' for while expression.")
        skipNL()
        consume(TokenKind.LPAREN, "Expect '(' before condition.")
        skipNL()
        let condition: Expr = expression()
        skipNL()
        consume(TokenKind.RPAREN, "Expect ')' after condition.")
        skipNL()
        let block: Block = block()
        WhileExpr(NodeIdManager.nextId(), condition, block)
    }

    private func loopExpression(): ?Expr {
        if (check(TokenKind.WHILE)) {
            return whileExpr()
        }
        None
    }

    private func jumpExpression(): ?Expr {
        if (check(TokenKind.RETURN)) {
            return returnExpr()
        }
        None
    }

    private func block(): Block {
        consume(TokenKind.LCURL, "Expect '{' before block.")
        let nodes = ArrayList<Node>()
        
        endStar()
        while (!check(TokenKind.RCURL) && !isAtEnd()) {
            // try {
            nodes.add(expressionOrDeclaration())
            // } catch (error: ParseError) {
            //     synchronize()
            // }
            endPlus()
        }
        consume(TokenKind.RCURL, "Expect '}' after block.")
        
        Block(NodeIdManager.nextId(), nodes.toArray())
    }

    private func expressionOrDeclaration(): Node {
        expression()
    }

    private func consume(kind: TokenKind, message: String): Token {
        if (check(kind)) { return advance() }
        throw error(peek(), message)
    }

    private func error(token: Token, message: String): ParseError {
        reporter.error(token, message)
        ParseError()
    }

    private func endStar(): Unit {
        while(matches(TokenKindHelper.END)) { }
    }

    private func endPlus(): Unit {
        if (matches(TokenKindHelper.END)) {
            endStar()
        } else {
            throw error(previous(), "Expected end of a statement")
        }
    }

    /*
    * Tries to skip the NL token and check if the next token is of the target kind.
    * If it is, advance and returns true.
    * If it's not it goes back to before the NL and returns false.
    */
    private func skipNLCompare(target: Array<TokenKind>): Bool {
        let tmp: Int64 = current
        skipNL()
        if (target.iterator().any({ t => check(t) })) {
            advance()
            return true
        }
        current = tmp
        return false
    }
}
