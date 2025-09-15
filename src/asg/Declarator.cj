package cjcj.asg

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

/*
* Declarator for the AST, allows to handle all declarations by visiting them.
*/
public open class Declarator <: Visitor<?Reference> {

    public Declarator(
        private let visitVar!: (VarDecl) -> ?Reference = { _ => None },
        private let visitFunc!: (FuncDecl) -> ?Reference = { _ => None },
        private let visitClass!: (ClassDecl) -> ?Reference = { _ => None },
        private let visitMain!: (MainDecl) -> ?Reference = { _ => None },
        public let canDeclare!: (String) -> Bool = { _ => true }
    ) {
    }

    public override func visit(funcDecl: FuncDecl): ?Reference {
        visitFunc(funcDecl)
    }
    
    public open override func visit(varDecl: VarDecl): ?Reference {
        visitVar(varDecl)
    }

    public override func visit(classDecl: ClassDecl): ?Reference {
        visitClass(classDecl)
    }

    public override func visit(mainDecl: MainDecl): ?Reference {
        visitMain(mainDecl)
    }
}
