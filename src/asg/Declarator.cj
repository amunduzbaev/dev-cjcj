package cjcj.asg

import cjcj.visitor.*

/*
* Declarator for the AST, allows to handle all declarations by visiting them.
*/
public open class Declarator <: Visitor<Unit> {

    public Declarator(
        private let visitVar!: (VarDecl) -> Unit = { _ => () },
        private let visitFunc!: (FuncDecl) -> Unit = { _ => () },
        private let visitClass!: (ClassDecl) -> Unit = { _ => () },
        private let visitMain!: (MainDecl) -> Unit = { _ => () }
    ) {
    }

    public override func visit(funcDecl: FuncDecl): Unit {
        visitFunc(funcDecl)
    }
    
    public open override func visit(varDecl: VarDecl): Unit {
        visitVar(varDecl)
    }

    public override func visit(classDecl: ClassDecl): Unit {
        visitClass(classDecl)
    }

    public override func visit(mainDecl: MainDecl): Unit {
        visitMain(mainDecl)
    }
}
