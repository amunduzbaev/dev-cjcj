package cjcj.parser

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.scanner.TokenKindHelper

import std.collection.ArrayList
import std.convert.Parsable

internal open class DeclParser {

    private static const MAX_PARAM_NUMBER = 255

    public DeclParser(private let helper: ParserHelper) {
    }

    func topLevelObject(): ?Node {
        if (helper.matches(TokenKind.FUNC)) {
            return functionDefinition()
        }
        if (helper.matches(TokenKind.LET, TokenKind.VAR)) {
            return variableDeclaration()
        }
        return None
    }

    private func declaration(): ?Decl {
        helper.skipNL()
        try {
            if (helper.matches(TokenKind.LET, TokenKind.VAR)) {
                return variableDeclaration()
            }
            if (helper.matches(TokenKind.FUNC)) {
                return functionDefinition()
            }
        } catch (error: ParseError) {
            helper.synchronize()
        }
        None
    }

    private func unnamedParameterList(): ArrayList<FuncParam> {
        let parameters: ArrayList<FuncParam> = ArrayList()
        do {
            helper.skipNL()
            if (parameters.size >= MAX_PARAM_NUMBER) {
                throw helper.error(helper.peek(), "Can't have more than " +
                    MAX_PARAM_NUMBER.toString() + " parameters.")
            }
            parameters.add(unnamedParameter())
            helper.skipNL()
        } while (helper.matches(TokenKind.COMMA) && helper.check(TokenKind.IDENTIFIER))
        return parameters
    }

    private func functionDefinition(): FuncDecl {
        let keyword: Token = helper.previous()
        helper.skipNL()
        let name: Token = helper.consume(TokenKind.IDENTIFIER, "Expect function name.")
        var parameters: ArrayList<FuncParam> = ArrayList()
        helper.skipNL()
        if (!helper.matches(TokenKind.UNIT_LITERAL)) {
            helper.consume(TokenKind.LPAREN, "Expect '(' before function parameters")
            helper.skipNL()
            parameters = unnamedParameterList()
            helper.skipNL()
            helper.consume(TokenKind.RPAREN, "Expect ')' after function parameters")
        }
        var declType: ?TypeNode = None
        helper.skipNL()
        if (helper.matches(TokenKind.COLON)) {
            helper.skipNL()
            let keyword = helper.advance()
            declType = nodeType(NodeIdManager.nextId(), name, keyword)
        }
        helper.skipNL()

        helper.consume(TokenKind.LCURL, "Expect '{' before main body.")
        let block: Block = block()
        helper.consume(TokenKind.RCURL, "Expect '}' after block.")
        FuncDecl(NodeIdManager.nextId(), keyword, name, block, parameters,
            declType)
    }

    private func nodeType(id: NodeId, name: Token, keyword: Token): TypeNode {
        try {
            return PrimitiveType(id, name, keyword)
        } catch (_: IllegalArgumentException) {
            return RefType(id, name, keyword)
        }
    }

    private func unnamedParameter(): FuncParam {
        if (helper.matches(TokenKind.IDENTIFIER, TokenKind.WILDCARD)) {
            let parameterName = helper.previous()
            helper.consume(TokenKind.COLON, "Expect ':' after parameter name")
            let keyword = helper.advance()
            FuncParam(NodeIdManager.nextId(),
            nodeType(NodeIdManager.nextId(), parameterName, keyword))
        } else {
            throw helper.error(helper.peek(), "Expected unnamed parameter")
        }
    }

    func mainDefinition(): MainDecl {
        var parameter: ?FuncParam = None
        var parameters: Int64 = 0
        if (!helper.matches(TokenKind.UNIT_LITERAL)) {
            helper.consume(TokenKind.LPAREN, "Expect '(' after main.")
            try { 
                if (!helper.check(TokenKind.RPAREN)) {
                    do {
                        if (parameters >= 1) {
                            throw helper.error(helper.peek(), "Can't have more than 1 parameter in main function.")
                        }
                        parameters++
                        parameter = unnamedParameter()

                        // For now, discards all other parameters other than the first one
                        // TEMPORARY FIX, REMEMBER TO MAKE A REAL SOLUTION

                    } while(helper.matches(TokenKind.COMMA))
                }
            } catch (error: ParseError) {
                helper.synchronize()
            }
            helper.consume(TokenKind.RPAREN, "Expect ') after parameters.")
        }

        var declType: ?TypeNode = None
        if (helper.matches(TokenKind.COLON)) {
            let keyword = helper.advance()
            declType = nodeType(NodeIdManager.nextId(), keyword, keyword)
        }

        helper.consume(TokenKind.LCURL, "Expect '{' before main body.")
        let block: Block = block()
        helper.consume(TokenKind.RCURL, "Expect '}' after block.")

        return MainDecl(NodeIdManager.nextId(), block, parameter, declType)

    }

    private func variableDeclaration(): VarDecl {
        let keyword: Token = helper.previous()

        helper.skipNL()
        let name: Token = helper.consume(TokenKind.IDENTIFIER, "Expect variable name.")

        var declType: ?TypeNode = None
        if (helper.matches(TokenKind.COLON)) {
            declType = nodeType(NodeIdManager.nextId(), name, helper.advance())
        }

        var initializer: ?Expr = None
        if (helper.matches(TokenKind.ASSIGN)) {
            initializer = expression()
        }

        VarDecl(NodeIdManager.nextId(),
            keyword, name, initializer, declType)
    }

    func block(): Block {
        let nodes = ArrayList<Node>()
        
        helper.endStar()
        while (!helper.check(TokenKind.RCURL) && !helper.isAtEnd()) {
            try {
                nodes.add(expressionOrDeclaration())
                helper.endPlus("Expect NL or SEMI after block component")
            } catch (error: ParseError) {
                helper.synchronize()
            }
        }
        Block(NodeIdManager.nextId(), nodes.toArray())
    }

    private func expressionOrDeclaration(): Node {
        if (let Some(decl) <- declaration()) {
            return decl
        }
        expression()
    }


    private func whileExpr(): Expr {
        helper.consume(TokenKind.WHILE, "Expected 'while' for while expression.")
        helper.skipNL()
        helper.consume(TokenKind.LPAREN, "Expect '(' before condition.")
        helper.skipNL()
        let condition: Expr = expression()
        helper.skipNL()
        helper.consume(TokenKind.RPAREN, "Expect ')' after condition.")
        helper.skipNL()
        helper.consume(TokenKind.LCURL, "Expect '{' before block.")
        let block: Block = block()
        helper.consume(TokenKind.RCURL, "Expect '}' after block.")
        WhileExpr(NodeIdManager.nextId(), condition, block)
    }

    private func loopExpression(): ?Expr {
        if (helper.check(TokenKind.WHILE)) {
            return whileExpr()
        }
        None
    }

    private func ifExpression(): Expr {
        helper.consume(TokenKind.IF, "Expected 'if' for if expression.")
        helper.skipNL()
        helper.consume(TokenKind.LPAREN, "Expect '(' before condition.")
        helper.skipNL()
        let condition: Expr = expression()
        helper.skipNL()
        helper.consume(TokenKind.RPAREN, "Expect ')' after condition.")
        helper.skipNL()
        helper.consume(TokenKind.LCURL, "Expect '{' before block.")
        let ifBlock: Block = block()
        helper.consume(TokenKind.RCURL, "Expect '}' after block.")
        
        helper.skipNL()
        var elseBranch: ?Expr = None
        if (helper.matches(TokenKind.ELSE)) {
            helper.skipNL()
            if (helper.check(TokenKind.IF)) {
                elseBranch = ifExpression()
            } else {
                helper.consume(TokenKind.LCURL, "Expect '{' before block.")
                elseBranch = block()
                helper.consume(TokenKind.RCURL, "Expect '}' after block.")
            }
        }
        IfExpr(NodeIdManager.nextId(), condition, ifBlock, elseBranch)
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
        if (helper.matches(TokenKind.LPAREN)) {
            helper.skipNL()
            if (!helper.check(TokenKind.RPAREN)) {
                do {
                    helper.skipNL()
                    arguments.add(Argument(NodeIdManager.nextId(),
                                            expression()))
                    helper.skipNL()
                } while (helper.matches(TokenKind.COMMA))
            }

            helper.consume(TokenKind.RPAREN, "Expect ')' after agruments.")
        } else {
            helper.consume(TokenKind.UNIT_LITERAL,
                "Expect '()' if no parameters are passed")
        }
        CallExpr(NodeIdManager.nextId(), callee, arguments)
    }

    private func assignmentExpression(): Expr {
        if (let Some(value) <- helper.tryParse({ =>
                /*
                * If I don't find the Assignment Operator I need to go back to
                * include my left value expression to the expression I will
                * eventually parse.
                */
                if (let Some(value) <- leftValueExpression() &&
                    helper.matches(TokenKindHelper.ASSIGNMENT_OPERATOR))  {
                    return AssignExpr(NodeIdManager.nextId(), value, logicConjunctionExpression())
                }
                None
            })
        ) {
            return value
        }
        logicDisjunctionExpression()
    }

    private func identifier(): ?Expr {
        if (helper.matches(TokenKind.IDENTIFIER)) {
            return RefExpr(NodeIdManager.nextId(), helper.previous())
        }
        None
    }

    private func logicDisjunctionExpression(): Expr {
        var expr: Expr = logicConjunctionExpression()
        while (helper.matches(TokenKind.OR)) {
            let oper: Token = helper.previous()
            helper.skipNL()
            let right: Expr = logicConjunctionExpression()
            expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func logicConjunctionExpression(): Expr {
        var expr: Expr = bitwiseDisjunctionExpression()
        while (helper.skipNLCompare(TokenKind.AND)) {
            let oper: Token = helper.previous()
            helper.skipNL()
            let right: Expr = bitwiseDisjunctionExpression()
            expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func bitwiseDisjunctionExpression(): Expr {
        var expr: Expr = bitwiseConjunctionExpression()
        while (helper.skipNLCompare(TokenKind.BITOR)) {
            let oper: Token = helper.previous()
            helper.skipNL()
            let right: Expr = bitwiseConjunctionExpression()
            expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func bitwiseConjunctionExpression(): Expr {
        var expr: Expr = equalityComparisonExpression()
        while (helper.skipNLCompare(TokenKind.BITAND)) {
            let oper: Token = helper.previous()
            helper.skipNL()
            let right: Expr = equalityComparisonExpression()
            expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func equalityComparisonExpression(): Expr {
        var expr: Expr = comparisonOrTypeExpression()
        while (helper.skipNLCompare(TokenKindHelper.EQUALITY_OPERATOR)) {
            let oper: Token = helper.previous()
            helper.skipNL()
            let right: Expr = comparisonOrTypeExpression()
            expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func comparisonOrTypeExpression(): Expr {
        var expr: Expr = additiveExpression()
        while (helper.skipNLCompare(TokenKindHelper.COMPARISON_OPERATOR)) {
            let oper: Token = helper.previous()
            helper.skipNL()
            let right: Expr = additiveExpression()
            expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func additiveExpression(): Expr {
        var expr: Expr = multiplicativeExpression()
        while (helper.skipNLCompare(TokenKindHelper.ADDITIVE_OPERATOR)) {
            let oper: Token = helper.previous()
            helper.skipNL()
            let right: Expr = multiplicativeExpression()
            expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
        }
        return expr
    }

    private func multiplicativeExpression(): Expr {
        var expr: Expr = exponentExpression()
        while (helper.skipNLCompare(TokenKindHelper.MULTIPLICATIVE_OPERATOR)) {
            let oper: Token = helper.previous()
            helper.skipNL()
            let right: Expr = exponentExpression()
            expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
        }
        expr
    }

    private func exponentExpression(): Expr {
        var expr: Expr = prefixUnaryExpression()
        while (helper.skipNLCompare(TokenKindHelper.EXPONENT_OPERATOR)) {
            let oper: Token = helper.previous()
            helper.skipNL()
            let right: Expr = prefixUnaryExpression()
            expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
        }
        expr
    }

    private func prefixUnaryExpression(): Expr {
        // TODO: now an expression like --5 is ok but in the future
        // we will add the inc and dec operators that will be after this so that
        // the problem will be solved.
        if (helper.matches(TokenKindHelper.PREFIX_UNARY_OPERATOR)) {
            let oper: Token = helper.previous()
            let right = prefixUnaryExpression()
            return UnaryExpr(NodeIdManager.nextId(), oper, right)
        }
        postfixExpression()
    }

    private func postfixExpression(): Expr {
        var expr: Expr = atomicExpression()
        var changed = true
        while (changed) {
            changed = false
            while (helper.check(TokenKind.LPAREN) || helper.check(TokenKind.UNIT_LITERAL)) {
                expr = callSuffix(expr)
                changed = true
            }
        }
        expr
    }

    private func atomicExpression(): Expr {
        if (helper.matches(TokenKindHelper.LITERAL_CONSTANT)) {
            return LitConstExpr(NodeIdManager.nextId(), helper.previous())
        }
        if (helper.check(TokenKind.IF)) {
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
        if (helper.matches(TokenKind.LPAREN)) {
            helper.skipNL()
            let expr: Expr = expression()
            helper.skipNL()
            helper.consume(TokenKind.RPAREN, "Expected ')' after expression.")
            return ParenExpr(NodeIdManager.nextId(), expr)
        }
        throw helper.error(helper.peek(), "Expect expression.")
    }

    private func returnExpr(): Expr {
        helper.consume(TokenKind.RETURN, "Expected 'return' for return expression")
        let keyword: Token = helper.previous()

        let value = helper.tryParse({ =>
            helper.skipNL()
            try {
                return expression()
            } catch (_) {
                //TODO: it's still printing the error even if we don't want to.
                println("The previous error is not real")
                return None
            }
        })
        ReturnExpr(NodeIdManager.nextId(), value, keyword)
    }


    private func jumpExpression(): ?Expr {
        if (helper.check(TokenKind.RETURN)) {
            return returnExpr()
        }
        if (helper.matches(TokenKind.CONTINUE, TokenKind.BREAK)) {
            return JumpExpr(NodeIdManager.nextId(), helper.previous())
        }
        None
    }
}