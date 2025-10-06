package cjcj.asg

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager

import std.ast.Position
import std.collection.ArrayList
import std.collection.ArrayStack
import std.deriving.Derive

/*
* Needed to know if I can do some operations inside the current scope, for example a return
* expression.
*/
@Derive[Equatable]
public enum ScopeType {
    NIL | BLOCK | BODY
}

/*
* Needed to know if I can do some operations inside the current global type, for example use the
* "this" keyword.
*/
@Derive[Equatable]
public enum GlobalType {
    NIL | BODY
}

/*
* Resolves a Program and retrieves the ASG root. Every variable and function reference will be bound
* to the link created on the declaration.
* Traverses the AST and keeps environments for declarations, every envinronment is able to supply
* liks to the declarations based on the identifier.
* Note: for function links we cannot know at this stage the exact function that is called, this will
* require a future step, for now the link is a dummy link to a function with the same identifier.
*/
public class AsgMaker <: Visitor<Node> {
    private var classEnvironment: Environment<String, ClassReference> = Environment()
    private var funcEnvironment: Environment<String, FuncReference> = Environment()

    // Needed to know if a function exists.
    private var funcNameEnvironment: Environment<String, FuncReference> = Environment()
    private var variableEnvironment: Environment<String, VariableReference> = Environment()

    private var currentScopeType: ScopeType = ScopeType.NIL
    private var currentGlobalType: GlobalType = GlobalType.NIL
    
    /*
    * Contains the variable references with declaration type that are waiting for the next scope to
    * begin before getting declared. An example is function parameters, they need to be declared
    * inside the block and we need a way to tell him.
    */
    private let waitingDeclarations: ArrayStack<VariableReference> = ArrayStack()

    /*
    * Resolves all of the function and variable references and returns the new
    * Program node that is the ASG root.
    */
    public func resolve(program: Program): Program {
        // TODO: We need to declare Any and in the future all the other builtin interfaces/structs
        // because they're not primitive types, so they are considered as RefType.
        let builtinIdentifiers: Array<Token> = [
            Token(TokenKind.IDENTIFIER, "Any", Position()),
            Token(TokenKind.IDENTIFIER, "String", Position())
        ]

        builtinIdentifiers.iterator().forEach({ t => 
            classEnvironment.declare(t.value, ClassReference(NodeIdManager.nextId(), t, true))
        })

        return (program.traverse(this) as Program).getOrThrow()
    }

    public override func visit(program: Program): Node {
        let globalDeclarator: Declarator = DeclaratorFactory.globalAstDeclarator(
            funcEnvironment, funcNameEnvironment, classEnvironment
        )
        program.decls.iterator().forEach({ d => d.traverse(globalDeclarator) })

        Program(NodeIdManager.nextId(), program.decls.iterator().map({ d =>
            (d.traverse(this) as Decl).getOrThrow() }).fold(ArrayList(), { acc, v => acc.add(v); acc }))
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
        let left: Expr = (assignExpr.left.traverse(this) as Expr).getOrThrow()
        let right: Expr = (assignExpr.right.traverse(this) as Expr).getOrThrow()
        AssignExpr(NodeIdManager.nextId(), left, right)
    }

    public override func visit(refExpr: RefExpr): Node {
        RefExprWithRef(NodeIdManager.nextId(), refExpr.identifier, get(refExpr.identifier.value))
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
        CallExprWithRef(NodeIdManager.nextId(), callee, arguments)
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

    public override func visit(jumpExpr: JumpExpr): Node {
        if (currentScopeType == ScopeType.BLOCK) {
            return JumpExpr(NodeIdManager.nextId(), jumpExpr.keyword)
        }

        println("Jump statement not side a block")
        throw Exception()
    }

    public override func visit(varDecl: VarDecl): Node {
        // Call the initializer first because there could be reference to previous variables with
        // the same identifier.
        var initializer: ?Expr = None
        if (let Some(initzer) <- varDecl.initializer) {
            initializer = initzer.traverse(this) as Expr
        }

        var declType: ?TypeNode = None
        if (let Some(dt) <- varDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }

        let reference: VariableReference

        if (currentScopeType == ScopeType.BODY) {
            reference = variableEnvironment.getLocal(varDecl.identifier.value).getOrThrow({ =>
                Exception("Variable should've been declared in body scope") })
        } else {
            reference = VariableReference(NodeIdManager.nextId(), varDecl.identifier,
                varDecl.keyword)
            declareVar(varDecl.identifier, reference)
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
        var declType: ?TypeNode = None
        if (let Some(dt) <- funcDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }

        let reference: FuncReference

        let funcHashConcat: String = TypeManager.funcHashConcat(
            funcDecl.identifier.value,
            Utils.fold(
                funcDecl.params.iterator().map({ p => p.paramType.typeName.value }),
                ArrayList()
            ).toArray()
        )
        if (funcEnvironment.isGlobal || currentScopeType == ScopeType.BODY) {
            reference = funcEnvironment.getLocal(funcHashConcat).getOrThrow({ =>
                Exception("Global or body func should've been declared in advance")})                
        } else {
            reference = FuncReference(NodeIdManager.nextId(), funcDecl.identifier)
            declareFunc(funcHashConcat, reference)
        }

        let paramRefs: ArrayList<VariableReference> = ArrayList()
        funcDecl.params.iterator()
            .map({ p => (p.traverse(this) as VariableReference).getOrThrow()})
            .forEach({ p =>
                paramRefs.add(p)
                waitingDeclarations.add(p)
            })
        reference.paramRef = paramRefs
        let block: Block = (funcDecl.block.traverse(this) as Block).getOrThrow()

        FuncDeclWithRef(NodeIdManager.nextId(), funcDecl.keyword, funcDecl.identifier, block,
            funcDecl.params, declType, reference)
    }

    public override func visit(mainDecl: MainDecl): Node {
        var declType: ?TypeNode = None
        if (let Some(dt) <- mainDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }
        let reference: MainReference = MainReference(NodeIdManager.nextId())
        if (let Some(p) <- mainDecl.param) {
            let pref: VariableReference = (p.traverse(this) as VariableReference).getOrThrow()
            waitingDeclarations.add(pref)
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
        if(!isGlobal()) {
            throw Exception("Classes can be declared at topLevel only")
        }

        let classReference: ClassReference  = classEnvironment.getLocal(classDecl.identifier.value)
            .getOrThrow({ => Exception("ClassReference should've been declared in advance") })

        let body = (classDecl.body.traverse(this) as Body).getOrThrow()

        let superTypes = ArrayList<TypeNode>()
        classDecl.superTypes.iterator().forEach({ superType => 
            let visitedSuperType = (superType.traverse(this) as TypeNode).getOrThrow()
            superTypes.add(visitedSuperType)
        })

        ClassDeclWithRef(NodeIdManager.nextId(), classDecl.keyword, classDecl.identifier, body,
            superTypes, classReference)
    }

    public override func visit(body: Body): Node {
        let precGlobalType: GlobalType = beginGlobal(GlobalType.BODY)
        let precScopeType: ScopeType = beginScope(ScopeType.BODY)

        let bodyDeclarator: Declarator = DeclaratorFactory.bodyAstDeclarator(
            funcEnvironment, funcNameEnvironment, variableEnvironment
        )

        body.decls.iterator().forEach({ d => d.traverse(bodyDeclarator) })
        let decls: ArrayList<Decl> = ArrayList()
        body.decls.iterator().forEach({ d => decls.add((d.traverse(this) as Decl).getOrThrow()) })

        endGlobal(precGlobalType)
        endScope(precScopeType)
        Body(NodeIdManager.nextId(), decls)
    }

    public override func visit(memberAccess: MemberAccess): Node {
        let baseExpr = memberAccess.baseExpr.traverse(this)
        MemberAccessWithRef(NodeIdManager.nextId(), baseExpr, memberAccess.field)
    }

    public override func visit(thisSuperExpr: ThisSuperExpr): Node {
        if (currentGlobalType != GlobalType.BODY) {
            throw Exception("Cannot invoke ${thisSuperExpr.keyword.value} outside of a class")
        }
        ThisSuperReference(NodeIdManager.nextId(), thisSuperExpr.keyword)
    }

    private func beginGlobal(newGlobalType: GlobalType): GlobalType {
        let precGlobalType: GlobalType = currentGlobalType
        currentGlobalType = newGlobalType
        precGlobalType
    }

    private func endGlobal(precGlobalType: GlobalType): Unit {
        currentGlobalType = precGlobalType
    }

    private func beginScope(newScopeType: ScopeType): ScopeType{
        let precScopeType: ScopeType = currentScopeType
        currentScopeType = newScopeType
        funcEnvironment = Environment(funcEnvironment)
        funcNameEnvironment = Environment(funcNameEnvironment)
        variableEnvironment = Environment(variableEnvironment)
        precScopeType
    }

    private func endScope(precScopeType: ScopeType): Unit {
        currentScopeType = precScopeType
        funcEnvironment = funcEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
        funcNameEnvironment = funcNameEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
        variableEnvironment = variableEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
    }

    private func declareVar(identifier: Token, value: VariableReference): Unit {
        let name: String = identifier.value
        if ((variableEnvironment.isGlobal && classEnvironment.getLocal(name).isSome()) ||
            funcNameEnvironment.getLocal(name).isSome())
        {
            throw Exception("Redefinition of declaration ${name}")
        }
        variableEnvironment.declare(identifier.value, value)
    }

    private func declareFunc(funcHashConcat: String, ref: FuncReference): Unit {
        if (funcNameEnvironment.getLocal(ref.identifier.value).isNone()) {
            funcNameEnvironment.declare(ref.identifier.value, ref)
        }
        funcEnvironment.declare(funcHashConcat, ref)
    }

    private func isTypeDeclared(typeName: Token): Bool {
        classEnvironment.getGlobal(typeName.value).isSome()
    }

    private func get(key: String): Reference {
        var tmpFuncEnv = funcNameEnvironment
        var tmpVarEnv = variableEnvironment
        while (!tmpFuncEnv.isGlobal && !tmpVarEnv.isGlobal) {
            if (let Some(fun) <- tmpFuncEnv.getLocal(key)) {
                // THIS IS NOT THE REAL REFERENCE, IT'S JUST A WAY TO SAY THAT IT EXISTS.
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
            // THIS IS NOT THE REAL REFERENCE, IT'S JUST A WAY TO SAY THAT IT EXISTS.
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

