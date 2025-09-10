package cjcj.asg

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager
import cjcj.asg.declarators.*

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
    // private var globalScope: Environment = Environment()

    private var classEnvironment: Environment<String, ClassReference> = Environment()
    private var funcEnvironment: Environment<String, FuncReference> = Environment()
    private var variableEnvironment: Environment<String, VariableReference> = Environment()

    private var currentScopeType: ScopeType = ScopeType.NIL
    private var refExists: ?Reference = None
    
    /*
    * Contains the variable references with declaration type that are waiting for the next scope to
    * begin before getting declared. An example is function parameters, they need to be declared
    * inside the block and we need a way to tell him.
    */
    private let waitingDeclarations: ArrayStack<(VariableReference, TypeNode)> = ArrayStack()

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
            classEnvironment.declare(t.value, ClassReference(NodeIdManager.nextId(), t))
        })
        return (program.traverse(this) as Program).getOrThrow()
    }

    public override func visit(program: Program): Node {
        let decls: ArrayList<Decl> = ArrayList()

        let topDecl = GlobalDeclarator(funcEnvironment, variableEnvironment, classEnvironment)
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
        get(refExpr.identifier.value)
    }

    public override func visit(block: Block): Node {
        let precScopeType = beginScope(ScopeType.BLOCK)

        let nodes: ArrayList<Node> = ArrayList()
        while (let Some((last, declType)) <- waitingDeclarations.remove()) {
            nodes.add(VarDeclWithRef(NodeIdManager.nextId(), last.keyword, last.identifier, last,
                declType))
            declareVar(last.identifier, last)
        }
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
        // Call the initializer first because there could be reference to previous variables with
        // the same identifier.
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
            } else {
                reference = VariableReference(NodeIdManager.nextId(), varDecl.identifier,
                    varDecl.keyword)
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
        funcParam.paramType.traverse(this)
        VariableReference(NodeIdManager.nextId(), funcParam.paramType.typeParameterName,
            Token(TokenKind.LET, "let", Position()))
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
        } else {
            reference = FuncReference(NodeIdManager.nextId(), funcDecl.identifier)
            declareFunc(funcDecl.identifier, reference)
        }

        let paramRefs: ArrayList<VariableReference> = ArrayList()
        funcDecl.params.iterator()
            .map({ p => ((p.traverse(this) as VariableReference).getOrThrow(), p.paramType)})
            .forEach({ p =>
                paramRefs.add(p[0])
                waitingDeclarations.add((p))
            })
        reference.paramRef = paramRefs
        let block: Block = (funcDecl.block.traverse(this) as Block).getOrThrow()

        FuncDeclWithRef(NodeIdManager.nextId(), funcDecl.keyword, funcDecl.identifier, block,
            funcDecl.params, declType, reference)
    }

    public override func visit(mainDecl: MainDecl): Node {
        refExists = None 

        var declType: ?TypeNode = None
        if (let Some(dt) <- mainDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }
        let reference: MainReference = MainReference(NodeIdManager.nextId())
        if (let Some(p) <- mainDecl.param) {
            let pref: VariableReference = (p.traverse(this) as VariableReference).getOrThrow()
            waitingDeclarations.add((pref, p.paramType))
            reference.paramRef = pref
        }
        let block: Block = (mainDecl.block.traverse(this) as Block).getOrThrow()
        MainDeclWithRef(NodeIdManager.nextId(), block, mainDecl.param, declType, reference)
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

        if(!isGlobal()) {
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

    // TODO: Think about removing scopeType body.
    public override func visit(body: Body): Node {
        let precScopeType = beginScope(ScopeType.BODY)

        let decls: ArrayList<Decl> = ArrayList()
        let topDecl = BodyDeclarator(funcEnvironment, variableEnvironment)
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

    public override func visit(memberAccess: MemberAccess): Node {
        let baseExpr = memberAccess.baseExpr.traverse(this)
        MemberAccess(NodeIdManager.nextId(), baseExpr, memberAccess.field)
    }

    private func beginScope(newScopeType: ScopeType): ScopeType{
        let precScopeType = currentScopeType
        currentScopeType = newScopeType
        funcEnvironment = Environment(funcEnvironment)
        variableEnvironment = Environment(variableEnvironment)
        precScopeType
    }

    private func endScope(precScopeType: ScopeType): Unit {
        currentScopeType = precScopeType
        funcEnvironment = funcEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
        variableEnvironment = variableEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
    }

    private func declareVar(identifier: Token, value: VariableReference): Unit {
        variableEnvironment.declare(identifier.value, value)
    }

    private func declareFunc(identifier: Token, value: FuncReference): Unit {
        funcEnvironment.declare(identifier.value, value)
    }

    private func declareClass(identifier: Token, value: ClassReference): Unit {
        classEnvironment.declare(identifier.value, value)
    }

    private func isTypeDeclared(typeName: Token): Bool {
        classEnvironment.getGlobal(typeName.value).isSome()
    }

    private func get(key: String): Reference {
        var tmpFuncEnv = funcEnvironment
        var tmpVarEnv = variableEnvironment
        while (!tmpFuncEnv.isGlobal && !tmpVarEnv.isGlobal) {
            if (let Some(fun) <- tmpFuncEnv.getLocal(key)) {
                return fun
            }
            if (let Some(va) <- tmpVarEnv.getLocal(key)) {
                return va
            }
            tmpFuncEnv = tmpFuncEnv.enclosing.getOrThrow()
            tmpVarEnv = tmpVarEnv.enclosing.getOrThrow()
        }
        if (let Some(clas) <- classEnvironment.getLocal(key)) {
            return clas
        }
        if (let Some(fun) <- tmpFuncEnv.getLocal(key)) {
            return fun
        }
        if (let Some(va) <- tmpVarEnv.getLocal(key)) {
            return va
        }
        throw Exception("${key} is undefined.")
    }

    private func isGlobal(): Bool {
        funcEnvironment.isGlobal && variableEnvironment.isGlobal
    }
}

