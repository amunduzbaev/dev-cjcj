package cjcj.asg

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager

import std.ast.Position
import std.collection.ArrayList
import std.collection.ArrayStack
import std.deriving.Derive
import std.collection.HashMap

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
* 
* TODO : use effect handlers to remove some parts and improve the code
*/
public class AsgMaker <: Visitor<Node> {
    private var environments = AsgEnvironments()
    private var superClassEnvironments = HashMap<String, AsgEnvironments>()

    /*
    * Resolves all of the function and variable references and returns the new
    * Program node that is the ASG root.
    */
    public func resolve(program: Program): Program {
        // TODO: We need to declare Any and in the future all the other builtin interfaces/structs
        // because they're not primitive types, so they are considered as RefType.
        let builtinClasses: Array<Token> = [
            Token(TokenKind.IDENTIFIER, "Any", Position()),
            Token(TokenKind.IDENTIFIER, "String", Position())
        ]
        let builtinInterfaces: Array<Token> = [
            Token(TokenKind.IDENTIFIER, "Hashable", Position()),
            Token(TokenKind.IDENTIFIER, "ToString", Position())
        ]

        builtinClasses.iterator().forEach({ t => 
            environments.classEnvironment.declare(t.value, 
                ClassReference(NodeIdManager.nextId(), t, true))
        })

        builtinInterfaces.iterator().forEach({ t => 
            environments.interfaceEnvironment.declare(t.value, 
                InterfaceReference(NodeIdManager.nextId(), t))
        })

        return try {
            (program.traverse(this) as Program).getOrThrow()
        } handle(noBlock: NoBlock) {
            throw Exception("The function ${noBlock.name.value} must have a block")
        }
    }

    public override func visit(program: Program): Node {
        let decls: ArrayList<Decl> = ArrayList()
        
        let globalDeclarator: Declarator = DeclaratorFactory.globalAstDeclaratorWithInterfaces(
            environments.funcEnvironment, 
            environments.classEnvironment, 
            environments.interfaceEnvironment
        )

        let unorderedRefDecls = ArrayList<(Decl, ?Reference)>()
        program.decls.iterator().forEach({ d =>
            unorderedRefDecls.add((d, d.traverse(globalDeclarator)))
        })

        let refDecls = DeclarationsTopSort().resolve(unorderedRefDecls)
        let asgDeclNodes = HashMap<Int64, Decl>()
        
        refDecls.iterator().forEach({ entry =>
            let (d, ref) = entry
            let refBox = Box(ref)
            try {
                asgDeclNodes.add(d.id.id, (d.traverse(this) as Decl).getOrThrow())
            } handle(_: ExistingReference) {
                let ret = refBox.value
                refBox.value = None
                resume with ret
            }
        })

        program.decls.iterator().forEach({ d => 
            decls.add(asgDeclNodes.get(d.id.id).getOrThrow())
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
        let left: Expr = (assignExpr.left.traverse(this) as Expr).getOrThrow()
        let right: Expr = (assignExpr.right.traverse(this) as Expr).getOrThrow()
        AssignExpr(NodeIdManager.nextId(), left, right)
    }

    public override func visit(refExpr: RefExpr): Node {
        RefExprWithRef(NodeIdManager.nextId(), refExpr.identifier, get(refExpr.identifier.value))
    }

    public override func visit(block: Block): Node {
        beginScope(ScopeType.BLOCK)

        let nodes: ArrayList<Node> = ArrayList()
        while (let Some((last, declType)) <- perform WaitingDeclaration()) {
            // nodes.add(VarDeclWithRef(NodeIdManager.nextId(), last.keyword, last.identifier, last,
            //     declType))
            declareVar(last.identifier, last)
        }

        try {
            block.nodes.iterator().forEach({ n => nodes.add(n.traverse(this)) })
        } handle(noBlock: NoBlock) {
            throw Exception("The function ${noBlock.name.value} must have a block")
        } handle(_: ExistingReference) {
            resume with None
        }

        let asgBlock = Block(NodeIdManager.nextId(), nodes)

        endScope()
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
        if (environments.currentScopeType == ScopeType.BLOCK) {
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
        if (environments.currentScopeType == ScopeType.BLOCK) {
            return JumpExpr(NodeIdManager.nextId(), jumpExpr.keyword)
        }

        println("Jump statement not side a block")
        throw Exception()
    }

    public override func visit(varDecl: VarDecl): Node {
        // Call the initializer first because there could be reference to previous variables with
        // the same identifier.
        let storedRef = perform ExistingReference()

        var initializer: ?Expr = None
        if (let Some(initzer) <- varDecl.initializer) {
            initializer = initzer.traverse(this) as Expr
        }

        var declType: ?TypeNode = None
        if (let Some(dt) <- varDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }

        let reference: VariableReference

        if (let Some(ref) <- storedRef) {
            reference = (ref as VariableReference).getOrThrow({ => 
                Exception("Reference given to variable declaration is not VariableReference")})
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

    /* TODO : remove waiting Declarations using effect handlers for better code */
    public override func visit(funcDecl: FuncDecl): Node {
        let storedRef = perform ExistingReference()
        
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
        let waitingDeclarations = ArrayStack<(VariableReference, TypeNode)>()
        funcDecl.params.iterator()
            .map({ p => ((p.traverse(this) as VariableReference).getOrThrow(), p.paramType)})
            .forEach({ p =>
                paramRefs.add(p[0])
                waitingDeclarations.add((p))
            })
        reference.paramRef = paramRefs
        let block: ?Block = try {
            if (let Some(realBlock) <- funcDecl.block) {
                (realBlock.traverse(this) as Block).getOrThrow()
            } else {
                perform NoBlock(funcDecl.identifier)
                None
            }
        } handle(_: WaitingDeclaration) {
            resume with waitingDeclarations.remove()
        } 

        FuncDeclWithRef(NodeIdManager.nextId(), funcDecl.keyword, funcDecl.identifier, block,
            funcDecl.params, declType, reference)
    }

    public override func visit(mainDecl: MainDecl): Node {
        perform ExistingReference()

        var declType: ?TypeNode = None
        if (let Some(dt) <- mainDecl.declType) {
            declType = dt.traverse(this) as TypeNode
        }
        let reference: MainReference = MainReference(NodeIdManager.nextId())
        let waitingDeclarations = ArrayStack<(VariableReference, TypeNode)>()
        if (let Some(p) <- mainDecl.param) {
            let pref: VariableReference = (p.traverse(this) as VariableReference).getOrThrow()
            waitingDeclarations.add((pref, p.paramType))
            reference.paramRef = pref
        }

        let block: Block = try {
            (mainDecl.block.traverse(this) as Block).getOrThrow()
        } handle(_: WaitingDeclaration) {
            resume with waitingDeclarations.remove()
        }
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
        let storedRef: ?Reference = perform ExistingReference()

        if(!isGlobal()) {
            throw Exception("Classes can be declared at topLevel only")
        }

        let originalEnvironments = environments
        environments = match (classDecl.superTypes.get(0)) {
            case Some(parentType) => 
                match (superClassEnvironments.get(parentType.typeName.value)) {
                    case Some(superClassEnvironment) => superClassEnvironment
                    case _ => environments
                }
            case _ => environments
        }

        let superTypes = ArrayList<TypeNode>()
        classDecl.superTypes.iterator().forEach({ superType => 
            let visitedSuperType = (superType.traverse(this) as TypeNode).getOrThrow()
            superTypes.add(visitedSuperType)
        })

        let classReference: ClassReference = 
        if (let Some(ref) <- storedRef) {
            (ref as ClassReference).getOrThrow({ => 
                Exception("Reference given to the class declaration is not ClassReference")})
        } else {
            throw Exception("Class ${classDecl.identifier.value} should've been declared " +
                "with the global declarator")
        }

        let body = try {
            (classDecl.body.traverse(this) as Body).getOrThrow()
        } handle(classEnvironment: ClassEnvironment) {
            superClassEnvironments.add(classDecl.identifier.value, classEnvironment.environments)
            resume with ()
        }

        environments = originalEnvironments

        ClassDeclWithRef(NodeIdManager.nextId(), classDecl.keyword, classDecl.identifier, body,
            superTypes, classReference)
    }

    public override func visit(body: Body): Node {
        beginGlobal(GlobalType.BODY)

        let decls: ArrayList<Decl> = ArrayList()
        let bodyDeclarator: Declarator = DeclaratorFactory.bodyAstDeclarator(
            environments.funcEnvironment, environments.variableEnvironment
        )
        let refDecls = ArrayList<(Decl, ?Reference)>()
        body.decls.iterator().forEach({ d =>
            refDecls.add((d, d.traverse(bodyDeclarator)))
        })
        
        refDecls.iterator().forEach({ entry =>
            let (d, ref) = entry
            let refBox = Box(ref)
            try {
                decls.add((d.traverse(this) as Decl).getOrThrow())
            } handle(_: ExistingReference) {
                let ret = refBox.value
                refBox.value = None
                resume with ret
            }
        })

        perform ClassEnvironment(environments)

        endGlobal()
        Body(NodeIdManager.nextId(), decls)
    }

    public override func visit(memberAccess: MemberAccess): Node {
        let baseExpr = memberAccess.baseExpr.traverse(this)
        MemberAccessWithRef(NodeIdManager.nextId(), baseExpr, memberAccess.field)
    }

    public override func visit(thisSuperExpr: ThisSuperExpr): Node {
        if (environments.currentGlobalType != GlobalType.BODY) {
            throw Exception("Cannot invoke ${thisSuperExpr.keyword.value} outside of a class")
        }
        ThisSuperReference(NodeIdManager.nextId(), thisSuperExpr.keyword)
    }

    public override func visit(interfaceDecl: InterfaceDecl) {
        let storedRef = perform ExistingReference()

        if(!isGlobal()) {
            throw Exception("Interfaces can be declared at topLevel only")
        }

        let interfaceReference: InterfaceReference 
        if (let Some(ref) <- storedRef) {
            interfaceReference = (ref as InterfaceReference).getOrThrow({ => 
                Exception("Reference given to the interface declaration is not ClassReference")})
        } else {
            throw Exception("Interface ${interfaceDecl.identifier.value} should've been declared" +
                " with the global declarator")
        }


        let body = try {
            (interfaceDecl.body.traverse(this) as Body).getOrThrow()
        } handle(_: NoBlock) {
            resume with ()
        } handle(_: ClassEnvironment) {
            resume with ()
        }

        let superTypes = ArrayList<TypeNode>()
        interfaceDecl.superTypes.iterator().forEach({ superType => 
            let visitedSuperType = (superType.traverse(this) as TypeNode).getOrThrow()
            superTypes.add(visitedSuperType)
        })

        InterfaceDeclWithRef(NodeIdManager.nextId(), interfaceDecl.keyword, interfaceDecl.identifier, 
            body,superTypes, interfaceReference)
    }

    private func beginGlobal(newGlobalType: GlobalType) {
        environments = AsgEnvironments(environments, ScopeType.NIL, newGlobalType)
    }

    private func beginScope(newScopeType: ScopeType){
        environments = AsgEnvironments(environments, newScopeType, 
            environments.currentGlobalType)
    }

    private func endGlobal() {
        endScope()
    }

    private func endScope() {
        environments = environments.enclosing.getOrThrow({ => 
            Exception("Trying to close the global scope")})
    }

    private func declareVar(identifier: Token, value: VariableReference): Unit {
        environments.declareVar(identifier, value)
    }

    private func declareFunc(identifier: Token, value: FuncReference): Unit {
        environments.declareFunc(identifier, value)
    }

    private func isTypeDeclared(typeName: Token): Bool {
        environments.isTypeDeclared(typeName)
    }

    // TODO : figure out what to do with the References of the function.
    private func get(key: String): Reference {
        environments.get(key)
    }

    private func isGlobal(): Bool {
        environments.isGlobal()
    }
}

