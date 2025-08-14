package cjcj.parser

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.scanner.TokenKindHelper

import std.collection.ArrayList
import std.convert.Parsable

public class ParseError <: Exception { }

public class NodeIdManager {
    private static var count: UInt64 = 0

    public static func nextId(): NodeId {
        let id = NodeId(count)
        count++
        id
    }
}

public class DeclParser {

    private static let MAX_PARAM_NUMBER = 255
    private let tokens: Array<Token>
    private let reporter: Reporter
    private var current: Int64 = 0


    public DeclParser(tokens: Array<Token>, reporter: Reporter) {
        this.tokens = tokens
        this.reporter = reporter
    }

    public func parse(): ?Array<Node> {
        var nodes: ArrayList<Node> = ArrayList()
        
        endStar()
        while (!isAtEnd() && !(peek().kind == TokenKind.MAIN)) {
            do {
                if(let Some(Obj) <- topLevelObject()) {
                    nodes.add(Obj)
                }
                if (!endPlus()) {
                    error(peek(), "Needs an end of the current TopLevelObject before the next one")
                }
            } while (!isAtEnd() && endPlus() && !(peek().kind == TokenKind.MAIN))
        }

        if(matches(TokenKind.MAIN)) {
            nodes.add(mainDefinition())
        }

        while (!isAtEnd() && endPlus()) {
            do {
                if(let Some(Obj) <- topLevelObject()) {
                    nodes.add(Obj)
                }
                if (!endPlus()) {
                    error(peek(), "Needs an end of the current TopLevelObject before the next one")
                }
            } while (!isAtEnd() && endPlus())
        }

        return nodes.toArray()
    }

    private func endStar() {
        while(matches(TokenKind.NL, TokenKind.SEMI)) {}
    }

    private func endPlus(): Bool {
        if(matches(TokenKind.NL, TokenKind.SEMI)) {
            endStar()
            return true
        }
        return false
    }

    private func topLevelObject(): ?Node {
        try {
            let modifiers: ArrayList<Modifier> = modifiers()
            skipNL()

            if (matches(TokenKind.CLASS)) {
                return classDefinition(modifiers)
            } else if (matches(TokenKind.FUNC)) {
                return functionDefinition(modifiers)
            } else if (matches(TokenKind.LET, TokenKind.VAR)) {
                return variableDeclaration(modifiers)
            } else if (matches(TokenKind.STRUCT)) {
                return structDefinition(modifiers)
            } else {
                throw error(peek(), "Found non-declaration in global scope.")
            }
        } catch (error: ParseError) {
            synchronize()
            return None
        }

    }

    private func node(modifiers: ArrayList<Modifier>): Node {
        if (let Some(decl) <- declaration(modifiers)) {
            return decl
        }
        return expression()
    }

    private func declaration(modifiers: ArrayList<Modifier>): ?Decl {
        skipNL()
        try {
            if (matches(TokenKind.LET, TokenKind.VAR)) {
                return variableDeclaration(modifiers)
            }
            if (matches(TokenKind.FUNC)) {
                return functionDefinition(modifiers)
            }
            
        } catch (error: ParseError) {
            synchronize()
        }

        None
        
    }

    private func unnamedParameterList(): ArrayList<FuncParam> {
        let parameters: ArrayList<FuncParam> = ArrayList()

        do {
            skipNL()
            if (parameters.size >= MAX_PARAM_NUMBER) {
                throw error(peek(), "Can't have more than " +
                    MAX_PARAM_NUMBER.toString() + " parameters.")
            }

            parameters.add(unnamedParameter())
            skipNL()
        } while(matches(TokenKind.COMMA) && peek().kind == (TokenKind.IDENTIFIER))

        
        return parameters
    }


    private func functionDefinition(modifiers: ArrayList<Modifier>): FuncDecl {

        for (modifier in modifiers) {
            if (!(TokenKindHelper.FUNCTION_MODIFIERS_TOKEN_KIND.contains(modifier.keyword.kind))) {
                error(modifier.keyword, "Wrong modifier for class Init definition")
            }
        }

        let keyword: Token = previous()
        skipNL()
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect function name.")
        var parameters: ArrayList<FuncParam> = ArrayList()
        skipNL()
        if (!matches(TokenKind.UNIT_LITERAL)) {
            consume(TokenKind.LPAREN, "Expect '(' before function parameters")
            skipNL()
            parameters = unnamedParameterList()
            skipNL()
            consume(TokenKind.RPAREN, "Expect ')' after function parameters")
        }
        var declType: ?TypeNode = None
        skipNL()
        if (matches(TokenKind.COLON)) {
            skipNL()
            let keyword = advance()
            declType = nodeType(NodeIdManager.nextId(), name, keyword)
        }
        skipNL()


        consume(TokenKind.LCURL, "Expect '{' before main body.")
        let block: Block = block()
        consume(TokenKind.RCURL, "Expect '}' after block.")


        FuncDecl(NodeIdManager.nextId(),
                keyword, name, block, modifiers, parameters, declType)

        
    }

    private func nodeType(id: NodeId, name: Token, keyword: Token): TypeNode {
        try {
            return PrimitiveType(id, name, keyword)
        } catch (_: IllegalArgumentException) {
            return RefType(id, name, keyword)
        }
    }

    private func unnamedParameter(): FuncParam {
        if (matches(TokenKind.IDENTIFIER, TokenKind.WILDCARD)) {
            let parameterName = previous()
            consume(TokenKind.COLON, "Expect ':' after parameter name")
            let keyword = advance()
            FuncParam(NodeIdManager.nextId(),
            nodeType(NodeIdManager.nextId(), parameterName, keyword))
        } else {
            throw error(peek(), "Expected unnamed parameter")
        }
    }

    private func classDefinition(modifiers: ArrayList<Modifier>): ClassDecl {

        // For now, the first inherited keyword is considered a className by the parser always, that is not always the truth
        // Before processing we can't tell the difference
        
        for (modifier in modifiers) {
            if (!(TokenKindHelper.CLASS_MODIFIERS_TOKEN_KIND.contains(modifier.keyword.kind))) {
                error(modifier.keyword, "Wrong modifier for class definition")
            }
        }
        let keyword: Token = previous()
        skipNL()
        let name: Token = className()
        skipNL()

        let supertypes: ArrayList<TypeNode> = superClass()
        consume(TokenKind.LCURL, "Expect '{' before class body.")
        let body: Body = classBody()

        ClassDecl(NodeIdManager.nextId(), keyword, name, modifiers, body, supertypes)

    }

    private func className(): Token {
        consume(TokenKind.IDENTIFIER, "Expect class name.")
    }

    private func superClass(): ArrayList<TypeNode> {
        let supertypes: ArrayList<TypeNode> = ArrayList()
        if (matches(TokenKind.UPPERBOUND)) {
            skipNL()
            supertypes.add(classType())
            
        }

        return supertypes
    }

    private func classType(): TypeNode {
        TypeNode(NodeIdManager.nextId(), consume(TokenKind.IDENTIFIER, "Expect superclass name"))
    }

    private func classBody(): Body {
        let classMemberDeclarations: ArrayList<Decl> = ArrayList()

        endStar()

        var modifierList: ArrayList<Modifier> = modifiers()

        while(!isAtEnd() && !matches(TokenKind.IDENTIFIER, TokenKind.RCURL)) {
            try {
                classMemberDeclarations.add(classMemberDeclaration(modifierList))
                modifierList = modifiers()
            } catch (error: ParseError) {
                synchronize()
            }
        }

        if(!isAtEnd() && previous().kind != TokenKind.RCURL) {
            skipNL()

            classMemberDeclarations.add( classPrimaryInit(modifierList) )

            skipNL()

            modifierList = modifiers()

            skipNL()
            while(!matches(TokenKind.RCURL)) {
                try {
                    classMemberDeclarations.add(classMemberDeclaration(modifierList))
                    endPlus()
                    modifierList = modifiers()
                } catch (error: ParseError) {
                    synchronize()
                }
            }
        }


        return Body(NodeIdManager.nextId(), classMemberDeclarations.toArray())
    }

    private func classPrimaryInit(modifiers: ArrayList<Modifier>): PrimaryCtorDecl {
        var parameters: ArrayList<FuncParam> = ArrayList()
        let keyword: Token = previous()

        if(!(modifiers.size == 1 && modifiers[0].keyword.kind == TokenKind.CONST)) {
            for (modifier in modifiers) {
                if (!(TokenKindHelper.STRUCT_MODIFIERS_TOKEN_KIND.contains(modifier.keyword.kind))) {
                    error(modifier.keyword, "Wrong modifier for class Init definition")
                }
            }
        }
        skipNL()

        if (!matches(TokenKind.UNIT_LITERAL)) {
            consume(TokenKind.LPAREN, "Expect '(' before PrimaryInit parameters")
            skipNL()
            parameters.add(all: classPrimaryInitParamLists() )
            skipNL()
            consume(TokenKind.RPAREN, "Expect ')' after PrimaryInit parameters")
        }

        skipNL()

        consume(TokenKind.LCURL, "Expect '{' before main body.")
        let block: Block = block()
        consume(TokenKind.RCURL, "Expect '}' after block.")

        return PrimaryCtorDecl(NodeIdManager.nextId(), keyword, block, modifiers, parameters)
    }

    private func classPrimaryInitParamLists(): ArrayList<FuncParam> {
        let params: ArrayList<FuncParam> = ArrayList()
        if (peek().kind == TokenKind.IDENTIFIER){ 
            params.add(all : unnamedParameterList())
        }
        let modifiers = modifiers()
        if(matches(TokenKind.LET, TokenKind.VAR)) {
            params.add(all : classUnnamedInitParamList(modifiers))
        }


        return params

    }

    private func classUnnamedInitParamList(modifiers_: ArrayList<Modifier>): ArrayList<FuncParam> {
        let params: ArrayList<FuncParam> = ArrayList()
        var mods = modifiers_
        do {
            params.add(classUnnamedParam(mods))
            mods = modifiers()
        } while(matches(TokenKind.LET, TokenKind.VAR))

        return params
    }

    private func classUnnamedParam(modifiers: ArrayList<Modifier>): FuncParam {
        let keyword: Token = previous()
        let parameterName = advance()
        consume(TokenKind.COLON, "Expect ':' after parameter name")
        let typ: Token = advance()
        FuncParam(NodeIdManager.nextId(), keyword, modifiers,nodeType(NodeIdManager.nextId(), parameterName, typ))
        
    }
    

    private func classMemberDeclaration(modifiers: ArrayList<Modifier>): Decl {
        let final: Decl
        skipNL()
        var flag: Bool = false
        for (modifier in modifiers) {
            if (modifier.keyword.kind == TokenKind.STATIC) {flag = true}
        }
        if (matches(TokenKind.INIT)) {
            if(flag) {
                final = staticInit(modifiers)
            } else {
                final = classInit(modifiers)
            }
        } else if (matches(TokenKind.VAR, TokenKind.LET)) {
            final = variableDeclaration(modifiers)
        } else if (matches(TokenKind.FUNC)) {
            final = functionDefinition(modifiers)
        } else {
            throw error(peek(), "Expected classMemberDeclaration")
        }
        endStar()
        return final

    }

    private func classInit(modifiers: ArrayList<Modifier>): Decl {
        let parameters: ArrayList<FuncParam> = ArrayList()
        let keyword: Token = previous()

        if(!(modifiers.size == 1 && modifiers[0].keyword.kind == TokenKind.CONST)) {
            for (modifier in modifiers) {
                // Using STRUCT MODIFIERS becaus ethey're the same as classInit
                if (!(TokenKindHelper.STRUCT_MODIFIERS_TOKEN_KIND.contains(modifier.keyword.kind))) {
                    error(modifier.keyword, "Wrong modifier for class Init definition")
                }
            }
        }
        skipNL()

        if (!matches(TokenKind.UNIT_LITERAL)) {

            consume(TokenKind.LPAREN, "Expect '(' before Init parameters")
            skipNL()
            parameters.add(all : classPrimaryInitParamLists() )
            skipNL()
            consume(TokenKind.RPAREN, "Expect ')' after Init parameters")
        }

        skipNL()

        consume(TokenKind.LCURL, "Expect LCURL before Static Init body")

        let block: Block = Block(NodeIdManager.nextId(), expressionOrDeclarations())

        consume(TokenKind.RCURL, "Expect RCURL after Static Init body")

        return FuncDecl(NodeIdManager.nextId(), keyword, block, modifiers, parameters)
    }

    private func staticInit(modifiers: ArrayList<Modifier>): Decl {
        let initkeyword: Token = previous()
        consume(TokenKind.UNIT_LITERAL, "Expect Unit Literal after Static Init")

        consume(TokenKind.LCURL, "Expect LCURL before Static Init body")

        let block: Block = Block(NodeIdManager.nextId(), expressionOrDeclarations())

        consume(TokenKind.RCURL, "Expect RCURL after Static Init body")

        let params: ArrayList<FuncParam> = ArrayList()

        return FuncDecl(NodeIdManager.nextId(), initkeyword, block, modifiers, params)

    }

    private func expressionOrDeclarations(): Array<Node> {
        endStar()
        let nodes: ArrayList<Node> = ArrayList()

        if(peek().kind != TokenKind.RCURL) {
            do {
                nodes.add(expressionOrDeclaration())
            } while (peek().kind != TokenKind.RCURL && endPlus())
        } 
        
        return nodes.toArray()
    }

    private func expressionOrDeclaration(): Node {
        let modifiers: ArrayList<Modifier> = modifiers()

        if (matches(TokenKind.FUNC)) {
            return functionDefinition(modifiers)
        }
        if (matches(TokenKind.VAR, TokenKind.LET)) {
            variableDeclaration(modifiers)
        }

        return expression()

    }

    private func body(): Array<Decl> {
        let nodes = ArrayList<Decl>()
        
        skipNL()
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
            skipNL()
        }
        consume(TokenKind.RCURL, "Expect '}' after body.")
        
        nodes.toArray()
    }

    private func structDefinition(modifiers: ArrayList<Modifier>): StructDecl {
        let keyword: Token = previous()
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect struct name.")
        let supertypes: ArrayList<TypeNode> = ArrayList()

        if (matches(TokenKind.UPPERBOUND)) {

            do {
                let currToken: TokenKind = peek().kind
                supertypes.add(TypeNode(NodeIdManager.nextId(), consume(currToken, "Expect supertype name")))
            } while(matches(TokenKind.BITAND))
        
        }

        consume(TokenKind.LCURL, "Expect '{' before struct body.")

        let body: Body = Body(NodeIdManager.nextId(), body())

        StructDecl(NodeIdManager.nextId(), keyword, name, modifiers, body, supertypes)

    }

    private func mainDefinition(): MainDecl {
        var parameter: ?FuncParam = None
        var parameters: Int64 = 0
        if (!matches(TokenKind.UNIT_LITERAL)) {
            consume(TokenKind.LPAREN, "Expect '(' after main.")
            try{ 
                if (!check(TokenKind.RPAREN)) {
                    do {
                        if (parameters >= 1) {
                            throw error(peek(), "Can't have more than 1 parameter in main function.")
                        }
                        parameters++
                        parameter = unnamedParameter()

                        // For now, discards all other parameters other than the first one
                        // TEMPORARY FIX, REMEMBER TO MAKE A REAL SOLUTION

                    } while(matches(TokenKind.COMMA))
                }
            }catch (error: ParseError) {
                synchronize()
            }
            consume(TokenKind.RPAREN, "Expect ') after parameters.")
        }

        var declType: ?TypeNode = None
        if (matches(TokenKind.COLON)) {
            let keyword = advance()
            declType = nodeType(NodeIdManager.nextId(), keyword, keyword)
        }

        consume(TokenKind.LCURL, "Expect '{' before main body.")
        let block: Block = block()
        consume(TokenKind.RCURL, "Expect '}' after block.")

        return MainDecl(NodeIdManager.nextId(), block, parameter, declType)

    }

    private func block(): Block {
        let nodes = ArrayList<Node>()
        
        skipNL()
        while (!check(TokenKind.RCURL) && !isAtEnd()) {
            try {
                nodes.add(node(modifiers()))
            } catch (error: ParseError) {
                synchronize()
            }
            skipNL()
        }
        
        return Block(NodeIdManager.nextId(), nodes.toArray())
    }


    private func variableDeclaration(modifiers: ArrayList<Modifier>): VarDecl {
        let keyword: Token = previous()

        skipNL()
        let name: Token = consume(TokenKind.IDENTIFIER, "Expect variable name.")

        var declType: ?TypeNode = None
        if (matches(TokenKind.COLON)) {
            declType = nodeType(NodeIdManager.nextId(), name, advance())
        }

        var initializer: ?Expr = None
        if (matches(TokenKind.ASSIGN)) {
            initializer = expression()
        }

        VarDecl(NodeIdManager.nextId(),
            keyword, name, initializer, modifiers, declType)
    }

    private func expression(): Expr {
        synchronize()
        Expr(NodeIdManager.nextId())
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
                peek().kind == TokenKind.STRUCT ||
                peek().kind == TokenKind.RPAREN
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

    // private func checkNext(kind: TokenKind): Bool { 
    //     if (isAtEnd()) {
    //         return false
    //     }
    //     peekNext().kind == kind
    // }

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

    // private func peekNext(): Token {
    //     tokens[current + 1]
    // }
    
    private func previous(): Token {
        tokens[current - 1]
    }

    private func skipNL(): Unit {
        if (check(TokenKind.NL)) {
            advance()
        }
    }
}

