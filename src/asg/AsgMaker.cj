package cjcj.asg

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager
import cjcj.parser.ParseError

import std.env.getStdOut

import std.ast.Position
import std.collection.ArrayList
import std.collection.ArrayStack
import std.collection.Map
import std.collection.HashMap
import std.deriving.Derive

/*
* Needed to know if I can do some operations inside the current scope, for
* example a return expression.
*/
@Derive[Equatable]
private enum ScopeType {
    NIL | BLOCK | BODY
}

/*
* Resolves a Program and retrieves the ASG root. Every variable and function
* reference will be bound to the node of the initialization. (declaration maybe?)
* The reference and call nodes will be different from the AST for this reason.
*
* Note: I'm using a few getOrThrow() functions without custom errors and without
* catching them because it's impossible that the as didn't work except if
* there's a bug in the as operator itself.
*/
public class AsgMaker <: Visitor<Node> {
    private var currentEnvironment: Environment = Environment()
    private var lastKilledEnvironment: ?Environment = None
    private var currentScopeType: ScopeType = ScopeType.NIL
    
    /*
    * Contains the references that are waiting for the next scope to begin
    * before getting declared. An example is function parameters, they need to
    * be declared inside the block and we need a way to tell him.
    */
    private let waitingDeclarations: ArrayStack<Reference> = ArrayStack()

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
        let left: Reference
        if (let Some(l) <- (assignExpr.left.traverse(this) as Reference)) {
            left = l
        } else {
            // TODO: This probably can never happen because it's an error caught
            // while parsing so we can probably remove it.
            println("No reference on the left part of an assignment")
            throw ParseError()
        }
        let right: Expr = (assignExpr.right.traverse(this) as Expr).getOrThrow()
        AssignExpr(NodeIdManager.nextId(), left, right)
    }

    public override func visit(refExpr: RefExpr): Node {
        get(refExpr.identifier)
    }

    public override func visit(block: Block): Node {
        beginScope()
        let precScopeType: ScopeType = currentScopeType
        currentScopeType = ScopeType.BLOCK

        while (let Some(last) <- waitingDeclarations.remove()) {
            declare(last.identifier, last)
        }
        let nodes: ArrayList<Node> = ArrayList()
        block.nodes.iterator().forEach({ n => nodes.add(n.traverse(this)) })

        currentScopeType = precScopeType
        let asgBlock = Block(NodeIdManager.nextId(), nodes)

        endScope()
        asgBlock
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
        let callee: FuncReference =
            (callExpr.callee.traverse(this) as FuncReference)
                .getOrThrow({ => println("Not calling a function.")
                ParseError() })

        let arguments: ArrayList<Argument> = ArrayList()
        callExpr.arguments.iterator().forEach({ a => arguments.add(
            (a.traverse(this) as Argument).getOrThrow()
        )})
        if (arguments.size != callee.params.size) {
            println("Invalid number of parameters, found ${arguments.size} " +
                "expected ${callee.params.size}")
            throw ParseError()
        }
        CallExpr(NodeIdManager.nextId(), callee, arguments)
    }

    public override func visit(returnExpr: ReturnExpr): Node {
        if (currentScopeType == ScopeType.BLOCK) {
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

        let ref: VariableReference
        if (let Some(initzer) <- initializer) {
            ref = VariableReference(NodeIdManager.nextId(), varDecl.identifier,
                declType, varDecl.keyword)
        } else if (declType.isNone()) {
            println("No explicit type without initializer")
            throw ParseError()
        } else {
            ref = VariableReference(NodeIdManager.nextId(), varDecl.identifier,
                declType, varDecl.keyword)
        }
        declare(varDecl.identifier, ref)

        let nodeId: NodeId = NodeIdManager.nextId()

        // TODO: Make this return an AssignExpr if there's an initializer
        // because variable declaration are not a thing in ASG.
        // TODO: Figure out what to do with VarDeclWithRef
        VarDeclWithRef(nodeId, varDecl.keyword, varDecl.identifier, ref, initializer,
            declType)
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
        
        let paramRefs: ArrayList<Reference> = ArrayList()
        let params: ArrayList<FuncParam> = ArrayList()
        funcDecl.params.iterator()
            .map({ p => (p.traverse(this) as FuncParam).getOrThrow()})
            .forEach({ p =>
                params.add(p)
                let pref = VariableReference(
                    NodeIdManager.nextId(), p.name, p.paramType,
                    // Using the LET keyword because parameters are not mutable.
                    Token(TokenKind.LET, "", p.name.pos))
                paramRefs.add(pref)
                waitingDeclarations.add(pref)
            })
        
        let block: Block = (funcDecl.block.traverse(this) as Block).getOrThrow()
        
        let reference: FuncReference = FuncReference(NodeIdManager.nextId(),
            funcDecl.identifier, declType,
            lastKilledEnvironment.getOrThrow(), params)
        declare(funcDecl.identifier, reference)
        
        let nodeId: NodeId = NodeIdManager.nextId()

        FuncDeclWithRef(nodeId, funcDecl.keyword, funcDecl.identifier,
            block, params, declType, paramRefs)
    }

    public override func visit(mainDecl: MainDecl): Node {
        let newMain = MainDeclWithRef()
        newMain.keyword = mainDecl.keyword
        if (let Some(dt) <- mainDecl.declType) {
            newMain.declType = dt.traverse(this) as TypeNode
        }
        let paramRefs: ArrayList<Reference> = ArrayList()
        if (let Some(p) <- mainDecl.param &&
            let Some(np) <- (p.traverse(this) as FuncParam)) {
            newMain.param = np
            let pref = VariableReference(
                NodeIdManager.nextId(), np.name, np.paramType,
                Token(TokenKind.LET, "", np.name.pos))
            paramRefs.add(pref)
            waitingDeclarations.add(pref)
        }
        newMain.block = (mainDecl.block.traverse(this) as Block).getOrThrow()
        newMain.id = NodeIdManager.nextId()
        newMain.paramRef = paramRefs
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
        lastKilledEnvironment = None
    }

    private func endScope(): Unit {
        lastKilledEnvironment = currentEnvironment
        currentEnvironment = currentEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
    }

    private func declare(identifier: Token, value: Reference): Unit {
        currentEnvironment.declare(identifier, value)
    }

    private func get(identifier: Token): Reference {
        currentEnvironment.get(identifier)
    }
}

// TODO : Make typechecking in the following way
// in a seperate file
