package cjcj.asg.declarators

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager

import std.env.getStdOut

import std.ast.Position
import std.collection.ArrayList
import std.collection.ArrayStack
import std.collection.Map
import std.collection.HashMap
import std.deriving.Derive

public open class BodyDeclarator <: Visitor<?Reference> {
    private var funcEnvironment: Environment<String, FuncReference>
    private var variableEnvironment: Environment<String, VariableReference>

    public init(
        funcEnvironment: Environment<String, FuncReference>,
        variableEnvironment: Environment<String, VariableReference>
    ) {
        this.funcEnvironment = funcEnvironment
        this.variableEnvironment = variableEnvironment
    }

    public open override func visit(varDecl: VarDecl): ?Reference {
        let ref: VariableReference = VariableReference(NodeIdManager.nextId(), 
            varDecl.identifier, varDecl.keyword)
        if (canDeclare(varDecl.identifier.value)) {
            variableEnvironment.declare(varDecl.identifier.value, ref)
        }
        ref
    }

    public override func visit(funcDecl: FuncDecl): ?Reference {
        let ref: FuncReference = FuncReference(NodeIdManager.nextId(), funcDecl.identifier)
        if (canDeclare(funcDecl.identifier.value)) {
            funcEnvironment.declare(funcDecl.identifier.value, ref)
        }
        ref
    }

    public override func visit(_: MainDecl): ?Reference {
        None
    }

    protected open func canDeclare(key: String): Bool {
        funcEnvironment.getLocal(key).isNone() && variableEnvironment.getLocal(key).isNone()
    }
}