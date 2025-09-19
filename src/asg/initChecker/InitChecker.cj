package cjcj.asg.initChecker

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager
import cjcj.parser.ParseError
import cjcj.prettyPrinter.PrettyPrinter
import std.env.getStdOut
import std.collection.Set
import std.collection.HashSet

import std.collection.ArrayList
import std.collection.ArrayStack
import std.ast.Position
import std.deriving.Derive

/*

TODO : Global functions and variables 
    Global access in variables, make sure used variables are referenced before the first call to 
    the function, (as variable initialization)
    Solution : By traversing in the order of declaration, go through the variable declarations and
    for each function give the first variable that uses this function to intialize. 
    Next, compare the first variable that uses this function with the first last varialbe that is
    used in the function block. If the used variable is declared after the first variable that calls
    the function, then it is an error, since we use the variable before its definition/declaration. 
    (In the future, For static variables similar check can be done probably)

*/

public open class InitChecker <: Visitor<Unit> {
    protected var declareEnvironment = Environment<Reference, Int64>()
    protected var initializeEnvironment = Environment<Reference, Int64>()
    protected var lastKilledEnvironment = Environment<Reference, Int64>()
    protected var currentScopeType: ScopeEnvironment = ScopeEnvironment()
    protected var waitingDeclaration = HashSet<Reference>()

    public init(declareEnvironment_: Environment<Reference, Int64>, 
        initializeEnvironment_: Environment<Reference, Int64>,
        lastKilledEnvironment_: Environment<Reference, Int64>, 
        currentScopeType_: ScopeEnvironment){
            declareEnvironment = declareEnvironment_
            initializeEnvironment = initializeEnvironment_
            lastKilledEnvironment = lastKilledEnvironment_
            currentScopeType = currentScopeType_
    }
    public init() {
    }

    public func resolve(program: Program) {
        program.traverse(this)
    }

    public func visit(program: Program) {
        program.decls.iterator().forEach({ decl => 
            decl.traverse(this)
        })
    }
 
    public func visit(binaryExpr: BinaryExpr) {
        binaryExpr.left.traverse(this)
        binaryExpr.right.traverse(this)
    }

    public func visit(unaryExpr: UnaryExpr) {
        unaryExpr.right.traverse(this)
    }

    public func visit(parenExpr: ParenExpr){
        parenExpr.parenthesizedExpr.traverse(this)
    }

    public func visit(assignExpr: AssignExpr) {
        assignExpr.right.traverse(this)

        if (let Some(refExpr) <- (assignExpr.left as RefExprWithRef)) {
            let varReference = (refExpr.ref as VariableReference).getOrThrow({ => 
                Exception("Can only assign to variables, can not assign to class or a function")})

            if (!isInitialized(varReference)) {
                initialize(varReference)
            } else if (varReference.keyword.kind == TokenKind.LET) {
                throw Exception("Mutation of immutable variable ${varReference.identifier.value}")
            }
        }
    }

    public open func visit(refExpr: RefExprWithRef) {
        match (refExpr.ref as VariableReference) {
            case Some(varReference) => 
                if (!isInitialized(varReference)) {
                    throw Exception("Variable ${varReference.identifier} is referenced" + 
                    " before initialization")
                    // The position of this reference is stored at the position of the token 
                    // refExpr.identifier
                }
            case _ => ()
        }
    }

    protected var blockType: ScopeType = ScopeType.BLOCK
    public func visit(block: Block) {
        beginScope(blockType)

        // Reset the blockType to default BLOCK
        blockType = ScopeType.BLOCK

        block.nodes.iterator().forEach({ node => 
            node.traverse(this)
        })

        endScope()
    }

    // lastKilledEnvironment contains the initializeEnvironment of elseBranch
    // We need to merge the variables that are in both initializeEnvironments
    private var inElseBranch: Bool = false
    public func visit(ifExpr: IfExpr) {
        let currentInElseBranch = inElseBranch

        inElseBranch = (ifExpr.elseBranch is IfExpr)
        ifExpr.elseBranch.traverse(this)
        let elseBranchInitializeEnvironment = lastKilledEnvironment

        ifExpr.condition.traverse(this)
        ifExpr.ifBlock.traverse(this)

        intersect(lastKilledEnvironment, elseBranchInitializeEnvironment)
        if (!currentInElseBranch) {
            let initialized = lastKilledEnvironment.elements.iterator().fold(ArrayList<Reference>(),
            {   acc, entry => 
                acc.add(entry[0])
                acc
            })

            initialize(initialized)
        }
    }

    public func visit(whileExpr: WhileExpr) {
        whileExpr.block.traverse(this)
        whileExpr.condition.traverse(this)
    }

    public func visit(callExpr: CallExprWithRef) {
        callExpr.arguments.iterator().forEach({ arg => 
            arg.traverse(this)
        })

        match (callExpr.callee as RefExprWithRef) {
            case Some(refExpr) => refExpr.ref = callExpr.ref.getOrThrow()
            case _ => ()
        }
        callExpr.callee.traverse(this)
    }

    public func visit(returnExpr: ReturnExpr) {
        match (returnExpr.expr) {
            case Some(expr) => expr.traverse(this)
            case _ => ()
        }
    }

    public func visit(varDecl: VarDeclWithRef) {
        declare(varDecl.ref)
        if (let Some(initzer) <- varDecl.initializer) {
            initzer.traverse(this)
            initialize(varDecl.ref)
        } else if (waitingDeclaration.remove(varDecl.ref)) {
            initialize(varDecl.ref)
        }

        if (let Some(declType) <- varDecl.declType) {
            declType.traverse(this)
        }
    }

    public func visit(funcDecl: FuncDeclWithRef) {
        funcDecl.funcRef.paramRef.getOrThrow().iterator().forEach({ ref => 
            waitingDeclaration.add(ref)
        })

        if (let Some(declType) <- funcDecl.declType) {
            declType.traverse(this)
        }

        blockType = ScopeType.FUNCBLOCK
        funcDecl.block.traverse(this)
    }

    public func visit(mainDecl: MainDeclWithRef) {
        if (let Some(ref) <- mainDecl.mainRef.paramRef) {
            waitingDeclaration.add(ref)
        }

        if (let Some(declType) <- mainDecl.declType) {
            declType.traverse(this)
        }

        blockType = ScopeType.FUNCBLOCK
        mainDecl.block.traverse(this)
    }

    public open func visit(classDecl: ClassDeclWithRef): Unit {
        ClassInitChecker(declareEnvironment, initializeEnvironment, 
            lastKilledEnvironment, currentScopeType, classDecl)
    }

    public func visit(argument: Argument) {
        argument.expr.traverse(this)
    }

    public func visit(memberAccess: MemberAccess) {
        memberAccess.baseExpr.traverse(this)
    }

    public func visit(_: LitConstExpr) {
    }

    public func visit(_: JumpExpr) {
    }

    public func visit(_: TypeNode) {
    }

    public func visit(_: PrimitiveType) {
    }

    public func visit(_: RefType) {
    }

    public func visit(_: PrimitiveTypeExpr) {
    }

    public func visit(_: VariableReference) {
        throw Exception("References should not be traversed")
    }

    public func visit(_: FuncReference) {
        throw Exception("References should not be traversed")
    }

    public func visit(_: ClassReference) {
        throw Exception("References should not be traversed")
    }

    protected func beginScope(newScopeType: ScopeType) {
        currentScopeType = ScopeEnvironment(newScopeType, currentScopeType)
        declareEnvironment = Environment(declareEnvironment)
        initializeEnvironment = Environment(initializeEnvironment)
    }

    protected func endScope(): Unit {
        currentScopeType = currentScopeType.enclosing.getOrThrow({ => 
            Exception("Trying to close the global scope") })
        lastKilledEnvironment = initializeEnvironment
        declareEnvironment = declareEnvironment.enclosing.getOrThrow({ =>
            Exception("Trying to close the global scope") })
        initializeEnvironment = initializeEnvironment.enclosing.getOrThrow({ =>
            Exception("Trying to close the global scope") })
    }

    protected open func declare(reference: Reference) {
        declareEnvironment.declare(reference, 0)
    }

    protected open func canCapture(reference: Reference) :Bool { 
        var declEnvironment = declareEnvironment
        var scopeType = currentScopeType

        while (!declEnvironment.isGlobal && !scopeType.isGlobal) {
            if (declEnvironment.getLocal(reference).isSome()) {
                return true;
            } else if (scopeType.currentScopeType == ScopeType.FUNCBLOCK) {
                return false;
            }
            declEnvironment = declEnvironment.enclosing.getOrThrow()
            scopeType = scopeType.enclosing.getOrThrow()
        }

        true
    }

    protected open func initialize(reference: Reference) {
        if (!isInitialized(reference)) {
            if (!canCapture(reference)) {
                throw Exception("Cannot capture variable ${reference.identifier.value} before " + 
                "initialization")
            }
            initializeEnvironment.declare(reference, 0)
        }
    }

    protected func initialize(references: ArrayList<Reference>) {
        references.iterator().forEach({ reference => 
            initialize(reference)
        })
    }

    protected open func isInitialized(reference: Reference) {
        initializeEnvironment.getGlobal(reference).isSome()
    }

    // Given two environments left and right
    // Stores the intersection of keys of environments in left
    protected func intersect<K, V> (left: Environment<K, V>, right: Environment<K, V>) where K <: 
            Hashable & Equatable<K> & ToString {
        let leftElementsArr = left.elements.toArray()
        leftElementsArr.iterator().forEach({ entry => 
            let (key, _) = entry
            if (!right.getLocal(key).isSome()) {
                left.destroy(key)
            }
        })
    }
}


/*
Extension of the Checker above that checks initialization of a class 
    TODO: Add "this"
    TODD: check init() function calls form a cycle. 
*/
private class ClassInitChecker <: InitChecker {
    private var enclosingClassReference: ClassReference
    private var initializedMemberVariables: Int64 = 0
    private var totalMemberVariables: Int64 = 0
    private var decls: Set<Reference> = HashSet<Reference>()

    init (declareEnvironment: Environment<Reference, Int64>, 
            initializeEnvironment: Environment<Reference, Int64>,
            lastKilledEnvironment: Environment<Reference, Int64>, 
            currentScopeType: ScopeEnvironment, classDecl: ClassDeclWithRef){

        super(declareEnvironment, initializeEnvironment, 
            lastKilledEnvironment, currentScopeType)
        enclosingClassReference = classDecl.ref

        classDecl.traverse(this)
    }

    public func visit(classDecl: ClassDeclWithRef) :Unit {
        classDecl.superTypes.iterator().forEach({ superType => 
            superType.traverse(this)
        })

        classDecl.body.traverse(this)
    }

    protected func visit(body: Body) {
        beginScope(ScopeType.BODY)

        totalMemberVariables = 0
        decls = HashSet<Reference>(body.decls.iterator().fold(ArrayList<Reference>(), { acc, decl =>
            if (let Some(varDecl) <- (decl as VarDeclWithRef)) {
                acc.add(varDecl.ref)
            } else if (let Some(funcDecl) <- (decl as FuncDeclWithRef)) {
                acc.add(funcDecl.funcRef)
            }
            acc
        }))
        let varDecls = body.decls.iterator().filter({decl => 
            if (decl is VarDeclWithRef) {
                totalMemberVariables++
                return true;
            }
            false
        })
        let initDecls = body.decls.iterator().fold(ArrayList<FuncDeclWithRef>(), {acc, decl => 
            if (let Some(funcDecl) <- (decl as FuncDeclWithRef) && 
                funcDecl.keyword.value == "init") {
                    acc.add(funcDecl)
                }
            acc
        })
        let funcDecls = body.decls.iterator().fold(ArrayList<FuncDeclWithRef>(), {acc, decl => 
            if (let Some(funcDecl) <- (decl as FuncDeclWithRef) && 
                funcDecl.keyword.value  != "init") {
                    acc.add(funcDecl)
                }
            acc
        })
 
        varDecls.forEach({ varDecl => varDecl.traverse(this) })
        initDecls.iterator().forEach({ initDecl => initVisit(initDecl) })
        initializedMemberVariables = totalMemberVariables
        funcDecls.iterator().forEach({ funcDecl => funcDecl.traverse(this) })

        endScope()
    }

    private func initVisit(initDecl: FuncDeclWithRef) {
        let initializedMemberVariablesBefore = initializedMemberVariables

        initDecl.funcRef.paramRef.getOrThrow().iterator().forEach({ ref => 
            waitingDeclaration.add(ref)
        })

        if (let Some(declType) <- initDecl.declType) {
            declType.traverse(this)
        }

        blockType = ScopeType.FUNCBLOCK
        initDecl.block.traverse(this)

        if (!allClassMembersInitialized) {
            throw Exception("Constructor function does not" + 
            " initialize all variables")
        }
        initializedMemberVariables = initializedMemberVariablesBefore
    }

    protected override func initialize(reference: Reference) {
        if (!isInitialized(reference)) {
            if (decls.contains(reference)) {
                initializedMemberVariables++
            } else if (!canCapture(reference)) {
                throw Exception("Cannot capture variable ${reference.identifier.value} before " + 
                "initialization")
            }
            initializeEnvironment.declare(reference, 0)
        }
    }

    protected override func isInitialized(reference: Reference) {
        if (decls.contains(reference)) {
            allClassMembersInitialized || initializeEnvironment.getGlobal(reference).isSome()
        } else {
            initializeEnvironment.getGlobal(reference).isSome()
        }
    }

    public func visit(refExpr: RefExprWithRef) {
        if (let Some(varReference) <- (refExpr.ref as VariableReference)) {
            if (!isInitialized(varReference)) {
                throw Exception("Variable ${varReference.identifier} is referenced" + 
                " before initialization")
                // The position of this reference is stored at the position of the token 
                // refExpr.identifier
            }
        } else if (let Some(funcReference) <- (refExpr.ref as FuncReference) && 
            decls.contains(funcReference) && !allClassMembersInitialized) {
            
            throw Exception("Member function ${funcReference.identifier} is referenced before all"+
                " member variables are initialized")
        }
    }

    private prop allClassMembersInitialized: Bool {
        get() { totalMemberVariables == initializedMemberVariables }
    }
}
