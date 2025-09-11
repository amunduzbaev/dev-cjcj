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

public abstract class DeclaratorFactory {
    public static func bodyDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        variableEnvironment: Environment<String, VariableReference>
    ): Declarator {
        Declarator(
            visitFunc: functionDeclaration(funcEnvironment),
            visitVar: variableDeclaration(variableEnvironment),
            canDeclare: canDeclare([
                { k => funcEnvironment.getLocal(k).isNone() },
                { k => variableEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    public static func globalDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        classEnvironment: Environment<String, ClassReference>
    ): Declarator {
        Declarator(
            visitFunc: functionDeclaration(funcEnvironment),
            visitClass: classDeclaration(classEnvironment),
            canDeclare: canDeclare([
                { k => funcEnvironment.getLocal(k).isNone() },
                { k => classEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    public static func functionDeclarator(
        funcEnvironment: Environment<String, FuncReference>
    ): Declarator {
        Declarator(
            visitFunc: functionDeclaration(funcEnvironment),
            canDeclare: canDeclare([
                { k => funcEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    public static func variableDeclarator(
        variableEnvironment: Environment<String, VariableReference>
    ): Declarator {
        Declarator(
            visitVar: variableDeclaration(variableEnvironment),
            canDeclare: canDeclare([
                { k => variableEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    public static func classDeclarator(
        classEnvironment: Environment<String, ClassReference>
    ): Declarator {
        Declarator(
            visitClass: classDeclaration(classEnvironment),
            canDeclare: canDeclare([
                { k => classEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    private static func variableDeclaration(
        environment: Environment<String, VariableReference>
    ): (VarDecl) -> ?Reference {
        { varDecl: VarDecl =>
            let ref: VariableReference = VariableReference(NodeIdManager.nextId(), 
                varDecl.identifier, varDecl.keyword)
            if (canDeclare({ k => environment.getLocal(k).isNone() })(varDecl.identifier.value)) {
                environment.declare(varDecl.identifier.value, ref)
            }
            ref
        }
    }

    private static func functionDeclaration(
        environment: Environment<String, FuncReference>
    ): (FuncDecl) -> ?Reference {
        { varDecl: FuncDecl =>
            let ref: FuncReference = FuncReference(NodeIdManager.nextId(), varDecl.identifier)
            if (canDeclare({ k => environment.getLocal(k).isNone() })(varDecl.identifier.value)) {
                environment.declare(varDecl.identifier.value, ref)
            }
            ref
        }
    }

    private static func classDeclaration(
        environment: Environment<String, ClassReference>
    ): (ClassDecl) -> ?Reference {
        { varDecl: ClassDecl =>
            let ref: ClassReference = ClassReference(NodeIdManager.nextId(), varDecl.identifier)
            if (canDeclare({ k => environment.getLocal(k).isNone() })(varDecl.identifier.value)) {
                environment.declare(varDecl.identifier.value, ref)
            }
            ref
        }
    }

    private static func canDeclare(predicates: Array<(String) -> Bool>): (String) -> Bool {
        { key => predicates.iterator().all({ p => p(key) }) }
    }

}