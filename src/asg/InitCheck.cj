package cjcj.asg

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager
import cjcj.parser.ParseError

import std.env.getStdOut

import std.collection.ArrayList
import std.ast.Position
import std.deriving.Derive

public class InitCheck <: Visitor< InitsRefs >{
    private let notInitialized_: ArrayList<(Reference, Node)> = ArrayList()// How to error properly
    private let cannotMutate_: ArrayList<(Reference, Node)> = ArrayList()// How to error properly
    private var lastNode: ?Node = None 
    // Maybe can store/restore lastNode in traverse for each node instead of doing it every
    // time you enter visit (cleaner InitCheck, maybe worse Node implementation)

    // Return type of all visit functions in InitCheck is InitsRefs
    // for explanation of members of InitsRefs, read above
    public func resolve(program: Program) : Unit {
        program.traverse(this)
    }
    
    // TODO : maybe traversing into some branches (TypeNode, ...) is not needed, 
    // so we might remove them later (make sure they are not needed)
    
    public override func visit(program: Program) : InitsRefs{
        let prev = lastNode
        lastNode = program
        
        var current = InitsRefs()

        program.decls.reverse()
        for (decl in program.decls) {
            let child = decl.traverse(this)

            current.mergeR(child)

            if( let Some(varDecl) <- (decl as VarDeclWithRef) ){
                notInitialized.add(all: current.isInitialized(varDecl.ref))

                // If global variable is not initialized (error)
                match (varDecl.initializer) {
                    case Some(initzer) => ()
                    case None => notInitialized.add((varDecl.ref, varDecl))
                }

                if(varDecl.keyword.kind != TokenKind.VAR){
                    cannotMutate.add(all: current.isMutated(varDecl.ref))
                }
            }
        }
        program.decls.reverse()

        lastNode = prev
        current
    }

    public override func visit(binaryExpr: BinaryExpr) : InitsRefs {
        let prev = lastNode
        lastNode = binaryExpr
        
        let right = binaryExpr.right.traverse(this) 
        let left = binaryExpr.left.traverse(this)

        left.mergeL(right)
        lastNode = prev
        left
    } 

    public override func visit(unaryExpr: UnaryExpr) : InitsRefs {
        let prev = lastNode
        lastNode = unaryExpr
        
        let current = unaryExpr.right.traverse(this)
        
        lastNode = prev
        current
    }

    public override func visit(parenExpr: ParenExpr) : InitsRefs {
        let prev = lastNode
        lastNode = parenExpr
        
        let current = parenExpr.parenthesizedExpr.traverse(this)

        lastNode = prev
        current
    }

    public override func visit(_: LitConstExpr) : InitsRefs {
        InitsRefs()
    }

    public override func visit(assignExpr: AssignExpr) : InitsRefs {
        let prev = lastNode
        lastNode = assignExpr
        
        let right = assignExpr.right.traverse(this) 
        // TODO : No Classes for now, so here we assume that assignExpr.left is a 
        // reference to a variable. Fix/Change when classes are added 
        if(let Some(ref) <- (assignExpr.left as Reference)) {
            right.assigned(ref, assignExpr)
            right.initialized(ref, assignExpr)
        }

        lastNode = prev
        right
    }
 
    public override func visit(block: Block) : InitsRefs {
        let prev = lastNode
        lastNode = block
        
        block.nodes.reverse()

        let current = InitsRefs()
        for(node in block.nodes){
            let child = node.traverse(this)
            
            current.mergeR(child)

            if( let Some(varDecl) <- (node as VarDeclWithRef) ){
                notInitialized.add(all: current.isInitialized(varDecl.ref))

                if(varDecl.keyword.kind != TokenKind.VAR){
                    cannotMutate.add(all: current.isMutated(varDecl.ref))
                }
            }
        }

        block.nodes.reverse()
        lastNode = prev
        current
    }

    public override func visit(ifExpr: IfExpr): InitsRefs {
        let prev = lastNode
        lastNode = ifExpr
        
        let elseBranch = 
        match (ifExpr.elseBranch) {
            case Some(eb) => eb.traverse(this)
            case _ => InitsRefs()
        }

        let condition = ifExpr.condition.traverse(this)
        condition.mergeL(ifExpr.ifBlock.traverse(this))
        condition.bramchMerge(elseBranch)

        lastNode = prev
        condition
    }

    public override func visit(whileExpr: WhileExpr): InitsRefs {
        let prev = lastNode
        lastNode = whileExpr
        
        let block = whileExpr.block.traverse(this)
        let condition = whileExpr.condition.traverse(this)

        condition.mergeL(block)

        condition.clearInits()
        lastNode = prev
        condition
    }

    public override func visit(callExpr: CallExpr) : InitsRefs {
        let prev = lastNode
        lastNode = callExpr
        
        let current = InitsRefs()

        for(a in callExpr.arguments){
            let child = a.traverse(this)
            
            current.mergeL(child)
        }

        let callee = callExpr.callee.traverse(this)

        current.mergeR(callee)
        lastNode = prev
        current
    }

    public override func visit(returnExpr: ReturnExpr): InitsRefs{
        let prev = lastNode
        lastNode = returnExpr
        
        let current = match (returnExpr.expr) {
            case Some(expr) => expr.traverse(this)
            case None => InitsRefs()
        }

        lastNode = prev
        current
    }

    public override func visit(varDecl: VarDeclWithRef): InitsRefs{
        let prev = lastNode
        lastNode = varDecl
        
        var current = InitsRefs()

        if(let Some(initzer) <- varDecl.initializer) {
            current = initzer.traverse(this)
        }
        
        if(let Some(declType) <- varDecl.declType) {
            current.mergeL(declType.traverse(this))
        }

        if(varDecl.initializer.isSome()) {
            current.initialized(varDecl.ref, varDecl)
        }

        lastNode = prev
        current
    }

    public override func visit(funcDecl: FuncDeclWithRef) : InitsRefs {
        let prev = lastNode
        lastNode = funcDecl
        
        let current = InitsRefs()
        funcDecl.paramRef.iterator().forEach({ p => 
            let child = p.traverse(this)
            current.mergeL(child)
        })

        match (funcDecl.declType) {
            case Some(declType) => current.mergeL(declType.traverse(this))
            case _ => ()
        }
        current.mergeL(funcDecl.block.traverse(this))

        current.clearInits()
        current.assignsMustBeInitialized()
        lastNode = prev
        current
    }

    public override func visit(mainDecl: MainDeclWithRef): InitsRefs {
        let prev = lastNode
        lastNode = mainDecl
        
        let current = InitsRefs()
        match (mainDecl.paramRef) {
            case Some(p) => 
                let child = p.traverse(this)
                current.mergeL(child)
            case _ => ()
        }

        match (mainDecl.declType) {
            case Some(declType) => current.mergeL(declType.traverse(this))
            case _ => ()
        }
        current.mergeL(mainDecl.block.traverse(this))

        current.clearInits()
        current.assignsMustBeInitialized()
        lastNode = prev
        current
    }

    public override func visit(argument: Argument): InitsRefs {
        let prev = lastNode
        lastNode = argument
        
        lastNode = prev
        argument.expr.traverse(this)
    }

    public override func visit(_: TypeNode): InitsRefs {
        InitsRefs()
    }

    public override func visit(_: PrimitiveType): InitsRefs {
        InitsRefs()
    }

    public override func visit(_: RefType): InitsRefs {
        InitsRefs()
    }

    public override func visit(_: FuncReference) : InitsRefs {
        InitsRefs()
    }

    public override func visit(varRef: VariableReference) : InitsRefs {
        let current = InitsRefs()
        match (lastNode) {
            case Some(node) => current.referenced(varRef, node)
            case _ => throw Exception("Not possible, program always has main")
        }
        current
    }

    public prop notInitialized: ArrayList<(Reference, Node)> {
        get() { notInitialized_ }
    }

    public prop cannotMutate: ArrayList<(Reference, Node)> {
        get() { cannotMutate_ }
    }
}
