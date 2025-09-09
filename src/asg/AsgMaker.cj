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
private class bodyDeclaror <: Visitor<?Reference> {
    private var currentEnvironment: Environment
    private let currentScope: ScopeType

    public init(environment: Environment, scopeType: ScopeType) {
        currentEnvironment = environment
        currentScope = scopeType
    }

    public override func visit(varDecl: VarDecl): ?Reference {
        // TODO : Might change, TBD
        match (currentScope) {
            case BODY => 
                let ref: VariableReference = VariableReference(NodeIdManager.nextId(), 
                    varDecl.identifier, None, varDecl.keyword)
                currentEnvironment.declareVar(varDecl.identifier, ref)
                ref
            case _ => 
                None
        }
    }

    public override func visit(funcDecl: FuncDecl): ?Reference {
        let ref: FuncReference = FuncReference(NodeIdManager.nextId(),
            funcDecl.identifier, None, Environment(), ArrayList<FuncParam>())
        currentEnvironment.declareFunc(funcDecl.identifier, ref)
        
        ref
    }

    public override func visit(_: MainDecl): ?Reference {
        None
    }

    public override func visit(classDecl: ClassDecl): ?Reference {
        let ref = ClassReference(NodeIdManager.nextId(), classDecl.identifier)
        currentEnvironment.declareClass(classDecl.identifier, ref)

        ref
    }
}

public class AsgMaker <: Visitor<Node> {
    private var globalScope: Environment = Environment()
    private var currentEnvironment: Environment = globalScope
    private var lastKilledEnvironment: ?Environment = None
    private var currentScopeType: ScopeType = ScopeType.NIL
    private var refExists: ?Reference = None
    
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
        // TODO: We need to declare Any and in the future all the other builtin interfaces / structs
        // because they're not primitive types, so they are considered as RefType.
        let builtinIdentifiers: Array<Token> = [
            Token(TokenKind.IDENTIFIER, "Any", Position()),
            Token(TokenKind.IDENTIFIER, "String", Position())
        ]

        builtinIdentifiers.iterator().forEach({ t => 
            currentEnvironment.declareClass(t, ClassReference(NodeIdManager.nextId(), t))
        })
        return (program.traverse(this) as Program).getOrThrow()
    }

    public override func visit(program: Program): Node {
        let decls: ArrayList<Decl> = ArrayList()

        let topDecl = bodyDeclaror(currentEnvironment, currentScopeType)
        let refDecls = ArrayList<(Decl, ?Reference)>()
        program.decls.iterator().forEach({ d =>
            refDecls.add((d, d.traverse(topDecl)))
        })
        
        refDecls.iterator().forEach({ entry =>
            let (d, ref) = entry
            refExists = ref
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
            throw AssignExprError()
        }
        let right: Expr = (assignExpr.right.traverse(this) as Expr).getOrThrow()
        AssignExpr(NodeIdManager.nextId(), left, right)
    }

    public override func visit(refExpr: RefExpr): Node {
        get(refExpr.identifier)
    }

    public override func visit(block: Block): Node {
        let precScopeType = beginScope(ScopeType.BLOCK)

        while (let Some(last) <- waitingDeclarations.remove()) {
            declareVar(last.identifier, last)
        }
        let nodes: ArrayList<Node> = ArrayList()
        block.nodes.iterator().forEach({ n => nodes.add(n.traverse(this)) })

        let asgBlock = Block(NodeIdManager.nextId(), nodes)

        endScope(precScopeType)
        asgBlock
    }

    public override func visit(ifExpr: IfExpr): Node {
        IfExpr(NodeIdManager.nextId(),
            (ifExpr.condition.traverse(this) as Expr).getOrThrow(),
            (ifExpr.ifBlock.traverse(this) as Block).getOrThrow(),
            (ifExpr.elseBranch.traverse(this) as Expr).getOrThrow())
    }

    public override func visit(whileExpr: WhileExpr): Node {
        WhileExpr(NodeIdManager.nextId(),
            (whileExpr.condition.traverse(this) as Expr).getOrThrow(),
            (whileExpr.block.traverse(this) as Block).getOrThrow())
    }

    public override func visit(callExpr: CallExpr): Node {
        let callee: Node = callExpr.callee.traverse(this)

        let arguments: ArrayList<Argument> = ArrayList()
        callExpr.arguments.iterator().forEach({ a => arguments.add(
            (a.traverse(this) as Argument).getOrThrow()
        )})
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
        throw ReturnExprError()
    }

    public override func visit(varDecl: VarDecl): Node {
        // Call the initializer first because there could be reference to
        // previous variables with the same identifier.
        let storedRef = refExists 
        refExists = None

        var initializer: ?Expr = None
        if (let Some(initzer) <- varDecl.initializer) {
            initializer = initzer.traverse(this) as Expr
        }

        var declType: ?TypeNode = None
        if (let Some(dt) <- varDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }

        let reference: VariableReference

        if (initializer.isSome() || declType.isSome()) {
            if (let Some(ref) <- storedRef) {
                reference = (ref as VariableReference).getOrThrow({ => 
                    Exception("Reference given to the variable declaration is not VariableReference")})
                reference.declType = declType
            } else {
                reference = VariableReference(NodeIdManager.nextId(), varDecl.identifier,
                    declType, varDecl.keyword)
                declareVar(varDecl.identifier, reference)
            }
        } else {
            println("No explicit type without initializer")
            throw VarDeclError()
        }

        let nodeId: NodeId = NodeIdManager.nextId()
        VarDeclWithRef(nodeId, varDecl.keyword, varDecl.identifier, reference, initializer,
            declType)
    }

    public override func visit(funcParam: FuncParam): Node {
        FuncParam(NodeIdManager.nextId(), funcParam.keyword,
            (funcParam.paramType.traverse(this) as TypeNode).getOrThrow({ => FuncParamError()}))
    }

    public override func visit(funcDecl: FuncDecl): Node {
        let storedRef = refExists
        refExists = None
        
        var declType: ?TypeNode = None
        if (let Some(dt) <- funcDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }

        let reference: FuncReference
        if (let Some(ref) <- storedRef) {
            reference = (ref as FuncReference).getOrThrow({ => 
                Exception("Reference given to the function declaration is not FuncReference")})

            reference.declType = declType
        } else {
            reference = FuncReference(NodeIdManager.nextId(),
                funcDecl.identifier, declType, Environment(), ArrayList<FuncParam>())
            declareFunc(funcDecl.identifier, reference)
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

        reference.environment = lastKilledEnvironment.getOrThrow({ => 
            Exception("BLock of a function is not in lastKilledEnvironment")})
        reference.params = params

        let nodeId: NodeId = NodeIdManager.nextId()

        FuncDeclWithRef(nodeId, funcDecl.keyword, funcDecl.identifier,
            block, params, declType, paramRefs, reference)
    }

    public override func visit(mainDecl: MainDecl): Node {
        refExists = None 

        var declType: ?TypeNode = None
        if (let Some(dt) <- mainDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }
        var param: ?FuncParam = None
        var paramRef: ?Reference = None
        if (let Some(p) <- mainDecl.param) {
            let np: FuncParam = (p.traverse(this) as FuncParam).getOrThrow()
            let pref = VariableReference(
                NodeIdManager.nextId(), np.name, np.paramType,
                Token(TokenKind.LET, "", np.name.pos))
            param = np
            waitingDeclarations.add(pref)
            paramRef = pref
        }
        let block = (mainDecl.block.traverse(this) as Block).getOrThrow()
        let id = NodeIdManager.nextId()
        MainDeclWithRef(id, block, param, declType, paramRef)
    }

    public override func visit(argument: Argument): Node {
        Argument(NodeIdManager.nextId(), argument.expr.traverse(this))
    }

    public override func visit(typeNode: TypeNode): Node {
        if(!isTypeDeclared(typeNode.typeName)) {
            throw Exception("Type is not declared")
        }
        TypeNode(NodeIdManager.nextId(), typeNode.typeParameterName, typeNode.typeName)
    }

    public override func visit(primitiveType: PrimitiveType): Node {
        PrimitiveType(NodeIdManager.nextId(), primitiveType.typeParameterName,
            primitiveType.typeName)
    }

    public override func visit(refType: RefType): Node {
        if(!isTypeDeclared(refType.typeName)) {
            throw Exception("Type is not declared")
        }
        RefType(NodeIdManager.nextId(), refType.typeParameterName, refType.typeName)
    }

    public override func visit(classDecl: ClassDecl): Node {
        let storedRef = refExists
        refExists = None

        if(!currentEnvironment.isGlobal) {
            throw Exception("Classes can be declared at topLevel only")
        }

        let classReference: ClassReference 
        if (let Some(ref) <- storedRef) {
            classReference = (ref as ClassReference).getOrThrow({ => 
                Exception("Reference given to the class declaration is not ClassReference")})
        } else {
            classReference = ClassReference(NodeIdManager.nextId(), classDecl.identifier)
            declareClass(classDecl.identifier, classReference)
        }

        let body = (classDecl.body.traverse(this) as Body).getOrThrow({ => 
            Exception("Body of a class has to be Body in ASG")})

        let superTypes = ArrayList<TypeNode>()
        classDecl.superTypes.iterator().forEach({ superType => 
            let visitedSuperType = (superType.traverse(this) as TypeNode).getOrThrow({ => 
                Exception("SuperTypes of classDecl have to be TypeNode") })
            superTypes.add(visitedSuperType)
        })

        ClassDeclWithRef(NodeIdManager.nextId(), classDecl.keyword, 
        classDecl.identifier, body, superTypes, classReference)
    }

    public override func visit(body: Body): Node {
        let precScopeType = beginScope(ScopeType.BODY)

        let decls: ArrayList<Decl> = ArrayList()
        let topDecl = bodyDeclaror(currentEnvironment, currentScopeType)
        let refDecls = ArrayList<(Decl, ?Reference)>()
        body.decls.iterator().forEach({ d =>
            refDecls.add((d, d.traverse(topDecl)))
        })
        
        refDecls.iterator().forEach({ entry =>
            let (d, ref) = entry
            refExists = ref
            decls.add((d.traverse(this) as Decl).getOrThrow())
        })

        endScope(precScopeType)
        Body(NodeIdManager.nextId(), decls)
    }

    public override func visit(memberAccess:MemberAccess): Node {
        let baseExpr = (memberAccess.baseExpr.traverse(this) as Expr).getOrThrow({ => 
            Exception("BaseExpr in MemberAccess has to be Expr in ASG")})
        MemberAccess(NodeIdManager.nextId(), baseExpr, memberAccess.field)
    }

    private func beginScope(newScopeType: ScopeType): ScopeType{
        let precScopeType = currentScopeType
        currentScopeType = newScopeType
        currentEnvironment = Environment(currentEnvironment)
        lastKilledEnvironment = None
        precScopeType
    }

    private func endScope(precScopeType: ScopeType): Unit {
        currentScopeType = precScopeType
        lastKilledEnvironment = currentEnvironment
        currentEnvironment = currentEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
    }

    private func declareVar(identifier: Token, value: Reference): Unit {
        currentEnvironment.declareVar(identifier, value)
    }

    private func declareFunc(identifier: Token, value: Reference): Unit {
        currentEnvironment.declareFunc(identifier, value)
    }

    private func declareClass(identifier: Token, value: Reference): Unit {
        currentEnvironment.declareClass(identifier, value)
    }
    private func isTypeDeclared(typeName: Token) {
        globalScope.isTypeDeclared(typeName)
    }

    private func get(identifier: Token): Reference {
        currentEnvironment.get(identifier)
    }
}

