package cjcj.parser

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.scanner.TokenKindHelper

import std.collection.ArrayList
import std.convert.Parsable

private type TK = TokenKind
private type TKH = TokenKindHelper


internal open class DeclParser {

    private static const MAX_PARAM_NUMBER = 255

    public DeclParser(private let helper: ParserHelper, private let reporter: Reporter) {
    }

    func topLevelObject(): ?Decl {
        if (let Some(funcDef) <- functionDefinition()) {
            return funcDef
        }
        if (let Some(varDecl) <- variableDeclaration()) {
            return varDecl
        }
        None
    }

    private func declaration(): ?Decl {
        helper.skipNL()
        try {
            if (let Some(varDecl) <- variableDeclaration()) {
                return varDecl
            }
            if (let Some(funcDef) <- functionDefinition()) {
                return funcDef
            }
        } catch (error: ParseError) {
            helper.synchronize()
        }
        None
    }

    private func unnamedParameterList(): ArrayList<FuncParam> {
        let parameters: ArrayList<FuncParam> = ArrayList()
        let start: (Token,Int64) = (helper.previous(), helper.current-1)
        if(helper.check(TK.IDENTIFIER)) {
            do {
                if (helper.check(TK.IDENTIFIER)) {
                    helper.skipNL()
                    if (parameters.size >= MAX_PARAM_NUMBER) {
                        throw helper.error(helper.previous(), "Can't have more than " +
                            MAX_PARAM_NUMBER.toString() + " parameters.", helper.current)
                    }
                    try {
                        parameters.add(unnamedParameter())
                    } catch(e: FinalError) {
                        helper.synchronizeBlockParenthesis(start[0], start[1])
                    }
                } else {
                    helper.error(helper.previous(), 
                    "Expected parameter name after comma", helper.current-1)
                    
                }
                helper.skipNL()
            } while (helper.matches(TK.COMMA))
        }
        return parameters
    }

    private func functionDefinition(): ?FuncDecl {
        if (!helper.matches(TK.FUNC)) {
            return None
        }
        let keyword: Token = helper.previous()
        helper.skipNL()
        let name: Token = helper.consume(TK.IDENTIFIER, "Expect function name.", helper.current)
        var parameters: ArrayList<FuncParam> = ArrayList()
        helper.skipNL()
            if (!helper.matches(TK.UNIT_LITERAL)) {
                helper.consume(TK.LPAREN, "Expect '(' before function parameters", helper.current)
                let start: (Token,Int64) = (helper.previous(), helper.current-1)
                helper.skipNL()
                try {
                    parameters = unnamedParameterList()
                    helper.skipNL()
                    helper.consume(TK.RPAREN, 
                    "Expect ')' after function parameters", helper.current)
                } catch(e: ConsumeError) {
                    if (helper.check(TK.LCURL)) {
                        reporter.pop()
                        reporter.unclosedDelimiterError(helper.peek(), start[0], start[1], helper.current)
                    } else {
                        helper.synchronizeBlockParenthesis(start[0],start[1])
                    }
                } catch(e: ParseError) {
                    helper.synchronizeBlockParenthesis(start[0],start[1])
                }
            }
        
        var declType: ?TypeNode = None
        helper.skipNL()
        if (helper.matches(TK.COLON)) {
            helper.skipNL()
            let keyword = helper.advance()
            declType = nodeType(NodeIdManager.nextId(), name, keyword)
        }
        helper.skipNL()

        let block: Block = block()
        FuncDecl(NodeIdManager.nextId(), keyword, name, block, parameters,
            declType)
    }

    private func nodeType(id: NodeId, typeParameterName: Token, typeName: Token): TypeNode {
        try {
            return PrimitiveType(id, typeParameterName, typeName)
        } catch (_: IllegalArgumentException) {
            return RefType(id, typeParameterName, typeName)
        }
    }

    private func unnamedParameter(): FuncParam {
        if (helper.matches(TK.IDENTIFIER, TK.WILDCARD)) {
            let parameterName = helper.previous()
            helper.consume(TK.COLON, "Expect ':' after parameter name", helper.current)
            let keyword = helper.advance()
            FuncParam(NodeIdManager.nextId(),
                nodeType(NodeIdManager.nextId(), parameterName, keyword))
        } else {
            throw helper.error(helper.peek(), 
            "Expected unnamed parameter, found '\u{001b}[31m${helper.peek().value}\u{001b}[0m'", 
            helper.current)
        }
    }

    func mainDefinition(): ?MainDecl {
        if (!helper.matches(TK.MAIN)) {
            return None
        }
        var parameter: ?FuncParam = None
        var parameters: Int64 = 0
        if (!helper.matches(TK.UNIT_LITERAL)) {
            helper.consume(TK.LPAREN, "Expect '(' after main.", helper.current)
            try { 
                if (!helper.check(TK.RPAREN)) {
                    do {
                        if (parameters >= 1) {
                            throw helper.error(helper.peek(),
                                "Can't have more than 1 parameter in main function.", 
                                helper.current)
                        }
                        parameters++
                        parameter = unnamedParameter()

                        // For now, discards all other parameters other than the
                        // first one.
                        // TEMPORARY FIX, REMEMBER TO MAKE A REAL SOLUTION

                    } while(helper.matches(TK.COMMA))
                }
            } catch (error: ParseError) {
                helper.synchronize()
            }
            helper.consume(TK.RPAREN, "Expect ') after parameters.", helper.current)
        }

        var declType: ?TypeNode = None
        if (helper.matches(TK.COLON)) {
            let keyword = helper.advance()
            declType = nodeType(NodeIdManager.nextId(), keyword, keyword)
        }
        let block: Block = block()

        return MainDecl(NodeIdManager.nextId(), block, parameter, declType)

    }

    private func variableDeclaration(): ?VarDecl {
        if (!helper.matches(TK.LET, TK.VAR)) {
            return None
        }
        let keyword: Token = helper.previous()

        helper.skipNL()
        let name: Token = helper.consume(TK.IDENTIFIER, "Expect variable name.", helper.current)

        var declType: ?TypeNode = None
        if (helper.matches(TK.COLON)) {
            declType = nodeType(NodeIdManager.nextId(), name, helper.advance())
        }

        var initializer: ?Expr = None
        if (helper.matches(TK.ASSIGN)) {
            initializer = expression()
        }

        VarDecl(NodeIdManager.nextId(),
            keyword, name, initializer, declType)
    }

    private func block(): Block {
        helper.consume(TK.LCURL, "Expect '{' before block.", helper.current)
        let nodes: ArrayList<Node> = expressionOrDeclarations()
        helper.endStar()
        helper.consume(TK.RCURL, "Expect '}' after block.", helper.current)
        Block(NodeIdManager.nextId(), nodes)
    }

    private func expressionOrDeclarations(): ArrayList<Node> {
        let expressionOrDeclarations: ArrayList<Node> = ArrayList()
        helper.endStar()
        while (!helper.isAtEnd() &&
                let Some(exprOrDecl) <- expressionOrDeclaration()) {
            expressionOrDeclarations.add(exprOrDecl)
        }
        expressionOrDeclarations
    }

    private func expressionOrDeclaration(): ?Node {
        try {
            if (let Some(decl) <- declaration()) {
                return decl
            }
            if (let Some(expr) <- expression()) {
                return expr
            } 
            if (helper.matches(TKH.END) || helper.check(TK.RCURL)) {
                return None
            }
            throw helper.error(helper.peek(), 
            "Expected expression or declaration inside block, found '\u{001b}[31m${helper.peek().value}\u{001b}[0m'",
            helper.current)
        } catch (e: ParseError) {
            helper.synchronize()
            Expr(NodeIdManager.nextId())
        }
    }


    private func whileExpr(): ?Expr {
        if (!helper.matches(TK.WHILE)) {
            return None
        }

        helper.skipNL()
        helper.consume(TK.LPAREN, "Expect '(' before condition.", helper.current)
        let start: (Token,Int64) = (helper.previous(), helper.current-1)
        helper.skipNL()
        var condition: Expr
        try {
            condition = expectExpression(expression,
            "Expected condition after while.")
            helper.skipNL()
            helper.consume(TK.RPAREN, "Expect ')' after condition.", helper.current)
        } catch (e: ParseError){
            helper.synchronizeBlockParenthesis(start[0], start[1])
            condition = Expr(NodeIdManager.nextId())
        }
        helper.skipNL()
        let block: Block = block()

        WhileExpr(NodeIdManager.nextId(), condition, block)
    }

    private func loopExpression(): ?Expr {
        if (let Some(whileExpr) <- whileExpr()) {
            return whileExpr
        }
        None
    }

    private func ifExpression(): ?Expr {
        if (!helper.matches(TK.IF)) {
            return None
        }
        helper.skipNL()
        helper.consume(TK.LPAREN, "Expect '(' before condition.", helper.current)
        let start: (Token,Int64) = (helper.previous(), helper.current-1)
        helper.skipNL()
        var condition: Expr
        try {
            condition = expectExpression(expression,
            "Expected condition after while.")
            helper.skipNL()
            helper.consume(TK.RPAREN, "Expect ')' after condition.", helper.current)
        } catch (e: ParseError){
            helper.synchronizeBlockParenthesis(start[0], start[1])
            condition = Expr(NodeIdManager.nextId())
        }
        helper.skipNL()

        let ifBlock: Block = block()
        helper.skipNL()
        var elseBranch: ?Expr = None
        if (helper.matches(TK.ELSE)) {
            helper.skipNL()
            if (let Some(ifExpr) <- ifExpression()) {
                elseBranch = ifExpr
            } else {
                elseBranch = block()
            }
        }
        return IfExpr(NodeIdManager.nextId(), condition, ifBlock, elseBranch)
    }


    public func expression(): ?Expr {
        try {
                return assignmentExpression()
            } catch (e: Exception) {
                helper.synchronize()
                return Expr(NodeIdManager.nextId())
            }
    }

    private func leftValueExpression(): ?Expr {
        return leftValueExpressionWithoutWildCard()
    }

    private func leftValueExpressionWithoutWildCard(): ?Expr {
        return identifier()
    }

    private func callSuffix(callee: Expr): ?Expr {
        let arguments: ArrayList<Argument> = ArrayList()
            if (helper.matches(TK.LPAREN)) {
                let start: (Token,Int64) = (helper.previous(), helper.current-1)
                try {
                helper.skipNL()
                if (!helper.check(TK.RPAREN)) {
                    do {
                        helper.skipNL()
                        arguments.add(
                            Argument(
                                NodeIdManager.nextId(),
                                expectExpression(
                                    expression,
                                    "Expected expression inside call suffix."
                                )
                            )
                        )
                        helper.skipNL()
                    } while (helper.matches(TK.COMMA))
                }
                helper.consume(TK.RPAREN, "Expect ')' after arguments.", helper.current)
            } catch (e: ParseError) {
                helper.synchronizeCallParenthesis(start[0], start[1])
            } catch (e: ConsumeError) {
                reporter.pop()
                reporter.unclosedDelimiterError(helper.peek(), start[0], start[1], helper.current)
            }
            
        } else if (!helper.matches(TK.UNIT_LITERAL)) {
            return None
        }
        CallExpr(NodeIdManager.nextId(), callee, arguments)
    }

    /*
    * Tries to parse an expression and throws an error with the given message if
    * no expression was found.
    */
    private func expectExpression<T>(function: () -> ?T, message: String): Expr
            where T <: Expr {
        return function().getOrThrow({ =>
            helper.error(helper.peek(), message, helper.current)
        })
    }

    private func assignmentExpression(): ?Expr {
        if (let Some(value) <- helper.tryParse({ =>
                /*
                * If I don't find the Assignment Operator I need to go back to
                * include my left value expression to the expression I will
                * eventually parse.
                */
                if (let Some(value) <- leftValueExpression() &&
                    helper.matches(TKH.ASSIGNMENT_OPERATOR) &&
                    let Some(right) <- logicConjunctionExpression())  {
                    return AssignExpr(NodeIdManager.nextId(), value, right)
                }
                None
            })
        ) {
            return value
        }
        logicDisjunctionExpression()
    }

    private func identifier(): ?Expr {
        if (helper.matches(TK.IDENTIFIER)) {
            return RefExpr(NodeIdManager.nextId(), helper.previous())
        }
        None
    }

    private func logicDisjunctionExpression(): ?Expr {
        if (let Some(e) <- logicConjunctionExpression()) {
            var expr: Expr = e
            while (helper.matches(TK.OR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(logicConjunctionExpression,
                    "Expected logicConjunctionExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func logicConjunctionExpression(): ?Expr {
        if (let Some(e) <- bitwiseDisjunctionExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TK.AND)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(bitwiseDisjunctionExpression,
                    "Expect bitwiseDisjunctionExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func bitwiseDisjunctionExpression(): ?Expr {
        if (let Some(e) <- bitwiseConjunctionExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TK.BITOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(bitwiseConjunctionExpression,
                    "Expect bitwiseConjuctionExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func bitwiseConjunctionExpression(): ?Expr {
        if (let Some(e) <- equalityComparisonExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TK.BITAND)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(equalityComparisonExpression,
                    "Expect equalityComparisonExpression after ${oper.value}")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func equalityComparisonExpression(): ?Expr {
        if (let Some(e) <- comparisonOrTypeExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TKH.EQUALITY_OPERATOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(comparisonOrTypeExpression,
                    "Expect comparisonOrTypeExpression after ${oper.value}")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func comparisonOrTypeExpression(): ?Expr {
        if (let Some(e) <- additiveExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TKH.COMPARISON_OPERATOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(additiveExpression,
                    "Expect additiveExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func additiveExpression(): ?Expr {
        if (let Some(e) <- multiplicativeExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TKH.ADDITIVE_OPERATOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(multiplicativeExpression,
                    "Expect multiplicativeExpression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func multiplicativeExpression(): ?Expr {
        if (let Some(e) <- exponentExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TKH.MULTIPLICATIVE_OPERATOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(exponentExpression,
                    "Expect exponent expression after '${oper.value}'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func exponentExpression(): ?Expr {
        if (let Some(e) <- prefixUnaryExpression()) {
            var expr: Expr = e
            while (helper.skipNLCompare(TKH.EXPONENT_OPERATOR)) {
                let oper: Token = helper.previous()
                helper.skipNL()
                let right: Expr = expectExpression(prefixUnaryExpression,
                "Expected a prefixUnaryExpression after '**', found '\u{001b}[31m${helper.peek().value}\u{001b}[0m'")
                expr = BinaryExpr(NodeIdManager.nextId(), expr, oper, right)
            }
            return expr
        }
        None
    }

    private func prefixUnaryExpression(): ?Expr {
        // TODO: now an expression like --5 is ok but in the future
        // we will add the inc and dec operators that will be after this so that
        // the problem will be solved.
        if (helper.matches(TKH.PREFIX_UNARY_OPERATOR)) {
            let oper: Token = helper.previous()
            let right: Expr = expectExpression(prefixUnaryExpression,
            "Expected a postfixExpression after ${oper.value}, found '\u{001b}[31m${helper.peek().value}\u{001b}[0m'")
            return UnaryExpr(NodeIdManager.nextId(), oper, right)
        }
        postfixExpression()
    }

    private func postfixExpression(): ?Expr {
        if (let Some(e) <- atomicExpression()) {
            var expr: Expr = e
            while (let Some(cs) <- callSuffix(expr)) {
                expr = cs
            }
            return expr
        } else {
            return None
        }
    }

    private func atomicExpression(): ?Expr {
        if (helper.matches(TKH.LITERAL_CONSTANT)) {
            return LitConstExpr(NodeIdManager.nextId(), helper.previous())
        }
        if (let Some(ifExpr) <- ifExpression()) {
            return ifExpr
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
        if (helper.matches(TK.LPAREN)) {
            helper.skipNL()
            let expr: Expr = expectExpression(expression,
                "Expect expression after '('")
            helper.skipNL()
            helper.consume(TK.RPAREN, "Expected ')' after expression.", helper.current)
            return ParenExpr(NodeIdManager.nextId(), expr)
        }
        None
    }

    private func returnExpr(): ?Expr {
        if (!helper.matches(TK.RETURN)) {
            return None
        }
        let keyword: Token = helper.previous()
        helper.endStar()
        ReturnExpr(NodeIdManager.nextId(), expression(), keyword)
    }


    private func jumpExpression(): ?Expr {
        if (let Some(retExpr) <- returnExpr()) {
            return retExpr
        }
        if (helper.matches(TK.CONTINUE, TK.BREAK)) {
            return JumpExpr(NodeIdManager.nextId(), helper.previous())
        }
        None
    }
}