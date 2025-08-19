package cjcj.asg

import cjcj.ast.*
import cjcj.scanner.Token

import std.collection.ArrayStack
import std.collection.Map
import std.collection.HashMap

public class Resolver <: Visitor {
    private let scopes: ArrayStack<Map<String, Bool>> = ArrayStack()

    public func resolve(program: Program): Unit {
        program.traverse(this)
    }

    public override func visit(_: Program): Unit {

    }

    public override func visit(_: Expr): Unit {

    }

    public override func visit(_: BinaryExpr): Unit { }

    public override func visit(_: UnaryExpr): Unit { }

    public override func visit(_: ParenExpr): Unit { }

    public override func visit(_: LitConstExpr): Unit { }

    public override func visit(_: AssignExpr): Unit { }

    public override func visit(_: RefExpr): Unit { }

    public override func visit(block: Block): Unit {
        beginScope()
        block.nodes.iterator().forEach({ n => n.traverse(this) })
        endScope()
    }

    public override func visit(_: IfExpr): Unit { }

    public override func visit(_: WhileExpr): Unit { }

    public override func visit(_: CallExpr): Unit { }

    public override func visit(_: ReturnExpr): Unit { }

    public override func visit(_: Decl): Unit { }

    public override func visit(varDecl: VarDecl): Unit {
        // Call the 'right' first because there could be reference to previous
        // variables with the same identifier
        if (let Some(initializer) <- varDecl.initializer) {
            resolve(initializer)
        }
        declare(varDecl.identifier)
        define(varDecl.identifier)
    }

    public override func visit(_: FuncParam): Unit { }

    public override func visit(_: FuncDecl): Unit { }

    public override func visit(_: Argument): Unit { }

    public override func visit(_: TypeNode): Unit { }

    public override func visit(_: PrimitiveType): Unit { }

    public override func visit(_: RefType): Unit { }

    private func beginScope(): Unit {
        scopes.add(HashMap<String, Bool>())
    }

    private func endScope(): Unit {
        scopes.remove()
    }

    private func declare(identifier: Token): Unit {
        if (let Some(top) <- scopes.peek()) {
            if (let Some(prec) <- top.addIfAbsent(identifier.value, false)) {
                println("ERROR, cannot redefine a variable with the same name" +
                    " in the same scope")
            }
        }
    }

    private func define(identifier: Token): Unit {
        if (let Some(top) <- scopes.peek()) {
            if (top.addIfAbsent(identifier.value, true).isNone()) {
                println("ERROR, cannot assign to an undeclared variable")
            }
        }
    }

    private func resolve(_: Expr): Unit {

    }
}