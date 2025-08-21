package cjcj.asg

import cjcj.ast.*
import cjcj.scanner.Token
import cjcj.parser.NodeIdManager
import cjcj.parser.ParseError

import std.env.getStdOut

import std.collection.ArrayList
import std.collection.ArrayStack
import std.collection.Map
import std.collection.HashMap
import std.deriving.Derive

@Derive[Equatable]
private enum ScopeType {
    NIL | BLOCK | BODY
}

/*
* Resolves a program and retrieves the ASG root. The ASG root will have
* only one declaration that is the MainDecl. Every variable and function
* reference will be bound to the node of the initialization.
* The reference and call nodes will be different from the AST for this reason.
*
* Note: I'm using a few getOrThrow() functions without custom errors and without
* catching them because it's impossible that the as didn't work except if
* there's a bug in the as operator itself.
*/
public class Resolver <: Visitor<Node> {
    private var currentEnvironment: Environment = Environment()
    private var currentScope: ScopeType = ScopeType.NIL

    /*
    * Resolves all of the function and variable references and returns the new
    * Program node that is the ASG root.
    */
    public func resolve(program: Program): Program {
        return (program.traverse(this) as Program).getOrThrow()
    }

    public override func visit(program: Program): Node {
        let decls: ArrayList<Decl> = ArrayList()
        program.decls.iterator().forEach({ d =>
            decls.add((d.traverse(this) as Decl).getOrThrow())
        })
        Program(NodeIdManager.nextId(), decls)
    }

    public override func visit(binaryExpr: BinaryExpr): Node {
        BinaryExpr(NodeIdManager.nextId(),
            binaryExpr.left.traverse(this),
            binaryExpr.oper,
            binaryExpr.right.traverse(this)
        )
    }

    public override func visit(unaryExpr: UnaryExpr): Node {
        UnaryExpr(NodeIdManager.nextId(), unaryExpr.oper,
            (unaryExpr.right.traverse(this) as Expr).getOrThrow())
    }

    public override func visit(parenExpr: ParenExpr): Node {
        ParenExpr(NodeIdManager.nextId(),
            (parenExpr.parenthesizedExpr.traverse(this) as Expr).getOrThrow())
    }

    public override func visit(litConstExpr: LitConstExpr): Node {
        LitConstExpr(NodeIdManager.nextId(), litConstExpr.literal)
    }

    public override func visit(assignExpr: AssignExpr): Node {
        // At the moment on the left there can only be an identifier, thats why
        // I'm checking only the RefExpr
        let left: Reference
        if (let Some(l) <- (assignExpr.left.traverse(this) as Reference)) {
            left = l
        } else {
            println("No identifier on the left part of an assignment")
            throw ParseError()
        }
        let value: Expr = (assignExpr.right.traverse(this) as Expr).getOrThrow()
        let ref: Reference = currentEnvironment.get(left.identifier)
        ref.value = value
        AssignExpr(NodeIdManager.nextId(), left, value)
    }

    public override func visit(refExpr: RefExpr): Node {
        // TODO: fix this, in this way you would not be able to assign a
        // function.
        (currentEnvironment.get(refExpr.identifier) as VariableReference)
            .getOrThrow({ => println("Variable reference is not a variable")
                ParseError()})
    }

    public override func visit(block: Block): Node {
        beginScope()
        let precScope: ScopeType = currentScope
        currentScope = ScopeType.BLOCK

        let nodes: ArrayList<Node> = ArrayList()
        block.nodes.iterator().forEach({ n => nodes.add(n.traverse(this)) })

        currentScope = precScope
        endScope()
        Block(NodeIdManager.nextId(), nodes)
    }

    public override func visit(ifExpr: IfExpr): Node {
        let elseBranch: ?Expr = match(ifExpr.elseBranch) {
            case Some(eb) => eb.traverse(this) as Expr
            case None => None
        }
        IfExpr(NodeIdManager.nextId(),
            (ifExpr.condition.traverse(this) as Expr).getOrThrow(),
            (ifExpr.ifBlock.traverse(this) as Block).getOrThrow(), elseBranch)
    }

    public override func visit(whileExpr: WhileExpr): Node {
        WhileExpr(NodeIdManager.nextId(),
            (whileExpr.condition.traverse(this) as Expr).getOrThrow(),
            (whileExpr.block.traverse(this) as Block).getOrThrow())
    }

    public override func visit(callExpr: CallExpr): Node {
        let identifier: Token

        // TODO: change this because it won't work with member access. See
        // todo at Reference.cj
        if (let Some(refExpr) <- (callExpr.callee as RefExpr)) {
            identifier = refExpr.identifier
        } else {
            println("Cannot call a function without an identifier!!")
            throw ParseError()
        }
        let ref: FuncReference = (
                currentEnvironment.get(identifier) as FuncReference
            ).getOrThrow({ => println("${identifier} is not a function")
                ParseError()})

        let arguments: ArrayList<Argument> = ArrayList()
        callExpr.arguments.iterator().forEach({ a => arguments.add(
            (a.traverse(this) as Argument).getOrThrow()
        )})
        ref.arguments = arguments
        ref
    }

    public override func visit(returnExpr: ReturnExpr): Node {
        if (currentScope == ScopeType.BLOCK) {
            return ReturnExpr(NodeIdManager.nextId(),
                match(returnExpr.expr) {
                    case Some(expr) => expr.traverse(this) as Expr
                    case None => None
                }, returnExpr.keyword)
        }
        println("Return statement not inside a function")
        throw ParseError()
    }

    public override func visit(varDecl: VarDecl): Node {
        // Call the initializer first because there could be reference to
        // previous variables with the same identifier.
        var initializer: ?Expr = None
        if (let Some(initzer) <- varDecl.initializer) {
            initializer = initzer.traverse(this) as Expr
        }
        var declType: ?TypeNode = None
        if (let Some(dt) <- varDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }
        declare(varDecl.identifier)
        if (let Some(initzer) <- initializer) {
            assign(varDecl.identifier,
                VariableReference(NodeIdManager.nextId(), varDecl.identifier,
                    declType, initzer))
        } else if (declType.isNone()) {
            println("No explicit type without initializer")
            throw ParseError()
        }
        VarDecl(NodeIdManager.nextId(), varDecl.keyword, varDecl.identifier, 
            initializer, declType)
    }

    public override func visit(funcParam: FuncParam): Node {
        FuncParam(NodeIdManager.nextId(), funcParam.keyword,
            (funcParam.paramType.traverse(this) as TypeNode).getOrThrow())
    }

    public override func visit(funcDecl: FuncDecl): Node {
        var declType: ?TypeNode = None
        if (let Some(dt) <- funcDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }
        
        let params: ArrayList<FuncParam> = ArrayList()
        funcDecl.params.iterator().forEach({ p =>
            params.add((p.traverse(this) as FuncParam).getOrThrow())})
        
        let block: Block = (funcDecl.block.traverse(this) as Block).getOrThrow()
        
        declare(funcDecl.identifier)
        assign(funcDecl.identifier, FuncReference(NodeIdManager.nextId(),
            funcDecl.identifier, declType, block, currentEnvironment, params,
            None))
        
        FuncDecl(NodeIdManager.nextId(), funcDecl.keyword, funcDecl.identifier,
            block, params, declType)
    }

    public override func visit(mainDecl: MainDecl): Node {
        let newMain = MainDecl()
        newMain.keyword = mainDecl.keyword
        if (let Some(dt) <- mainDecl.declType) {
            newMain.declType = dt.traverse(this) as TypeNode
        }
        if (let Some(p) <- mainDecl.param) {
            newMain.param = (p.traverse(this) as FuncParam).getOrThrow()
        }
        newMain.block = (mainDecl.block.traverse(this) as Block).getOrThrow()
        newMain.id = NodeIdManager.nextId()
        newMain
    }

    public override func visit(argument: Argument): Node {
        Argument(NodeIdManager.nextId(), argument.expr.traverse(this))
    }

    public override func visit(typeNode: TypeNode): Node {
        TypeNode(NodeIdManager.nextId(), typeNode.typeParameterName)
    }

    public override func visit(primitiveType: PrimitiveType): Node {
        PrimitiveType(NodeIdManager.nextId(), primitiveType.typeParameterName,
            primitiveType.keyword)
    }

    public override func visit(refType: RefType): Node {
        RefType(NodeIdManager.nextId(), refType.typeParameterName,
            refType.identifier)
    }

    private func beginScope(): Unit {
        currentEnvironment = Environment(currentEnvironment)
    }

    private func endScope(): Unit {
        currentEnvironment = currentEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
    }

    private func declare(identifier: Token): Unit {
        currentEnvironment.declare(identifier)
    }

    private func assign(identifier: Token, value: Reference): Unit {
        currentEnvironment.assign(identifier, value)
    }
}