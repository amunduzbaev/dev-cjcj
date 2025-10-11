package cjcj.asg.initChecker

import cjcj.asg.Utils
import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.asg.ClassReferenceForTC

import std.collection.HashSet
import std.collection.ArrayList
import std.collection.ArrayStack
import std.collection.HashMap

public open class InitChecker <: DefaultVisitor<Unit> {
    protected var declareEnvironment = Environment<Reference, Int64>()
    protected var initializeEnvironment = Environment<Reference, Int64>()
    protected var currentScopeType: ScopeEnvironment = ScopeEnvironment()
    protected var lastKilledEnvironment = Environment<Reference, Int64>()
    protected var classMembersContainer: Environment<String, ClassReferenceForTC>

    public init(
        declareEnvironment_: Environment<Reference, Int64>, 
        initializeEnvironment_: Environment<Reference, Int64>,
        lastKilledEnvironment_: Environment<Reference, Int64>, 
        currentScopeType_: ScopeEnvironment,
        classMembersContainer: Environment<String, ClassReferenceForTC>
    ){
            super(())
            declareEnvironment = declareEnvironment_
            initializeEnvironment = initializeEnvironment_
            lastKilledEnvironment = lastKilledEnvironment_
            currentScopeType = currentScopeType_
            this.classMembersContainer = classMembersContainer
    }

    public init(classMembersContainer: Environment<String, ClassReferenceForTC>) {
        super(())
        this.classMembersContainer = classMembersContainer
    }

    public func resolve(program: Program) {
        try {
            program.traverse(this)
        } handle(exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception("Variable ${exactVarReference.varReference.identifier} is" + 
                "referenced before initialization in reference " + 
                "${exactVarReference.locationRef.getOrThrow().value}")
                // The position of this reference is stored at the position of the token 
                // refIdentifier
            }
            resume with ()
        } handle(_: MemberVarReference) {
            resume with ()
        }
        StaticGlobalVariableInitializationChecker(program)
    }

    public open override func visit(assignExpr: AssignExpr) {
        assignExpr.right.traverse(this)

        try {
            assignExpr.left.traverse(this)
        } handle(exactVarReference: ExactVarReference) {
            let varReference = exactVarReference.varReference

            if (!isInitialized(varReference)) {
                initialize(varReference)
            } else if (varReference.keyword.kind == TokenKind.LET) {
                throw Exception("Mutation of immutable variable" + 
                "${varReference.identifier.value}")
            }
            resume with ()
        } handle(memberVarReference: MemberVarReference) {
            let varReference = memberVarReference.varReference

            if (varReference.keyword.kind == TokenKind.LET) {
                throw Exception("Mutation of immutable member variable" + 
                "${varReference.identifier.value}")
            }
            resume with ()
        }
        // For error reporting use the locationRef in MemberVarReference or ExactVarReference
    }

    public override open func visit(varReference: VariableReference) {
        perform ExactVarReference(varReference)
    }

    public override open func visit(refExpr: RefExprWithRef) {
        try {
            refExpr.ref.getOrThrow().traverse(this)
        } handle(exactVarReference: ExactVarReference) {
            exactVarReference.locationRef = refExpr.identifier
            perform exactVarReference
            resume with ()
        }
    }

    public override func visit(block: Block) {
        beginScope(perform InferBlockType())

        while (let Some(paramReference) <- perform ParameterDeclaration()) {
                declare(paramReference)
                initialize(paramReference)
        }

        try {
            block.nodes.iterator().forEach({ node => 
                    node.traverse(this)
            })
        } handle(_: InferBlockType) {
            resume with ScopeType.BLOCK
        } handle(ifElseInit: IfElseInitialization<Reference, Int64>) {
            let initialized = ifElseInit.branchInitializations.elements.iterator().fold(
                ArrayList<Reference>(), { acc, entry => 
                    acc.add(entry[0])
                    acc
                })

            initialize(initialized)
            resume with ()
        } handle(exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception("Variable ${exactVarReference.varReference.identifier} is" + 
                "referenced before initialization in reference " + 
                "${exactVarReference.locationRef.getOrThrow().value}")
                // The position of this reference is stored at the position of the token 
                // refIdentifier
            }
            resume with ()
        } handle(_: MemberVarReference) {
            resume with ()
        }

        endScope()
    }

    // lastKilledEnvironment contains the initializeEnvironment of elseBranch
    // We need to merge the variables that are in both initializeEnvironments
    public override func visit(ifExpr: IfExpr) {
        try{
            ifExpr.elseBranch.traverse(this)
        } handle(_: IfElseInitialization<Reference, Int64>) {
            resume with ()
        }
        let elseBranchInitializeEnvironment = lastKilledEnvironment

        ifExpr.condition.traverse(this)
        ifExpr.ifBlock.traverse(this)

        intersect(lastKilledEnvironment, elseBranchInitializeEnvironment)
        perform IfElseInitialization(lastKilledEnvironment)
    }

    // TODO : Maybe we can use effect handlers for this, maybe NOT?
    public override open func visit(callExpr: CallExprWithRef) {
        callExpr.arguments.iterator().forEach({ arg => 
            arg.traverse(this)
        })

        match (callExpr.callee as RefExprWithRef) {
            case Some(refExpr) => refExpr.ref = callExpr.ref.getOrThrow()
            case _ => ()
        }
        callExpr.callee.traverse(this)
    }

    public override func visit(varDecl: VarDeclWithRef) {
        declare(varDecl.ref)
        if (let Some(initzer) <- varDecl.initializer) {
            initzer.traverse(this)
            initialize(varDecl.ref)
        }

        if (let Some(declType) <- varDecl.declType) {
            declType.traverse(this)
        }
    }

    public override func visit(funcDecl: FuncDeclWithRef) {
        if (let Some(declType) <- funcDecl.declType) {
            declType.traverse(this)
        }

        let paramRef = Utils.foldToStack(funcDecl.funcRef.paramRef.getOrDefault({ 
            => ArrayList<VariableReference>()}).iterator(), ArrayStack<VariableReference>())
        try {
            funcDecl.block.traverse(this)
        } handle(_: ParameterDeclaration) {
            resume with paramRef.remove()
        } handle(_: InferBlockType) {
            resume with ScopeType.FUNCBLOCK
        }
    }

    public override func visit(mainDecl: MainDeclWithRef) {
        if (let Some(declType) <- mainDecl.declType) {
            declType.traverse(this)
        }

        let paramRef = ArrayStack<VariableReference>()
        match (mainDecl.mainRef.paramRef) {
            case Some(varReference) => paramRef.add(varReference)
            case _ => ()
        }

        try{
            mainDecl.block.traverse(this)
        } handle(_: ParameterDeclaration) {
            resume with paramRef.remove()
        } handle(_: InferBlockType) {
            resume with ScopeType.FUNCBLOCK
        }
    }

    public override open func visit(classDecl: ClassDeclWithRef): Unit {
        ClassInitChecker(declareEnvironment, initializeEnvironment, 
            lastKilledEnvironment, currentScopeType, classDecl, classMembersContainer)
    }

    public override open func visit(memberAccess: MemberAccessWithRef): Unit {
        try {
            memberAccess.baseExpr.traverse(this)
        } handle(exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception("Variable ${exactVarReference.varReference.identifier} is" + 
                "referenced before initialization in reference " + 
                "${exactVarReference.locationRef.getOrThrow().value}")
            }
            resume with ()
        } handle(_: MemberVarReference) {
            resume with ()
        }

        match (classMembersContainer.getGlobal(memberAccess.ref.getOrThrow().identifier.value)
            .getOrThrow().getMembersReference(memberAccess.field.value)){
            case Some(ref) => 
                try {
                    ref.traverse(this)
                } handle(exactVarReference: ExactVarReference) {
                    perform MemberVarReference(exactVarReference.varReference, memberAccess.field)
                    resume with ()
                }
            case _ => ()
        }
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
    TODO: Add "this" and fixed member access
    TODD: check init() function calls form a cycle. 
*/
private class ClassInitChecker <: InitChecker {
    private var accessibleMembers: ClassReferenceForTC
    private var initializedMemberVariables: Int64 = 0
    private var totalMemberVariables: Int64 = 0
    private var superIsInitialized: Bool = false
    private var decls: HashSet<Reference> = HashSet<Reference>()
    private let unvisitedConstructors = HashMap<Reference, FuncDeclWithRef>()
    private let currentPathConstructors = HashSet<Reference>()

    init (
        declareEnvironment: Environment<Reference, Int64>, 
        initializeEnvironment: Environment<Reference, Int64>,
        lastKilledEnvironment: Environment<Reference, Int64>, 
        currentScopeType: ScopeEnvironment, 
        classDecl: ClassDeclWithRef, 
        classMembersContainer: Environment<String, ClassReferenceForTC>
    ){

        super(declareEnvironment, initializeEnvironment, 
            lastKilledEnvironment, currentScopeType, classMembersContainer)
        accessibleMembers = classMembersContainer.getGlobal(classDecl.identifier.value).getOrThrow({
            => Exception("Can not find the class ${classDecl.identifier.value} in class Member" + 
            " Containers")
        })

        classDecl.traverse(this)
    }

    public override func visit(classDecl: ClassDeclWithRef) :Unit {
        classDecl.superTypes.iterator().forEach({ superType => 
            superType.traverse(this)
        })

        classDecl.body.traverse(this)
    }

    // TODO : fix the body visitor (remove as)
    // I need to think if this can be improved without use of a new visitor
    // Currently I believe that this is not possible, but maybe we can use effect handlers for this
    public override func visit(body: Body) {
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

        initDecls.iterator().forEach({ initDecl => 
            unvisitedConstructors.add(initDecl.funcRef, initDecl) })

        varDecls.forEach({ varDecl => varDecl.traverse(this) })
        initDecls.iterator().forEach({ initDecl => tryVisitConstructor(initDecl.funcRef) })
        initializedMemberVariables = totalMemberVariables
        funcDecls.iterator().forEach({ funcDecl => funcDecl.traverse(this) })

        endScope()
    }

    public override func visit(funcReference: FuncReference) {
        perform ExactFuncReference(funcReference)
    }

    public override func visit(refExpr: RefExprWithRef) {
        try {
            refExpr.ref.getOrThrow().traverse(this)
        } handle(exactVarReference: ExactVarReference) {
            exactVarReference.locationRef = refExpr.identifier
            perform exactVarReference

            resume with ()
        } handle(exactFuncReference: ExactFuncReference) {
            let funcReference = exactFuncReference.funcReference
            if (decls.contains(funcReference) && !allClassMembersInitialized) {
                throw Exception("Member function ${funcReference.identifier} is referenced before" +
                " all member variables are initialized")
            }
            resume with ()
        }
    }

    public override func visit(memberAccess: MemberAccessWithRef) {
        try {
            memberAccess.baseExpr.traverse(this)
        } handle(exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception("Variable ${exactVarReference.varReference.identifier} is" + 
                "referenced before initialization in reference " + 
                "${exactVarReference.locationRef.getOrThrow().value}")
            }
            resume with ()
        } handle(_: MemberVarReference) {
            resume with ()
        }

        match (classMembersContainer.getGlobal(memberAccess.ref.getOrThrow().identifier.value)
            .getOrThrow().getMembersReference(memberAccess.field.value)) {
            case Some(ref) => 
                try {
                    ref.traverse(this)
                } handle(exactVarReference: ExactVarReference) {
                    if (memberAccess.baseExpr is ThisSuperExpr) {
                        exactVarReference.locationRef = memberAccess.field
                        perform exactVarReference
                    } else {
                        perform MemberVarReference(exactVarReference.varReference, memberAccess.field)
                    }
                    resume with ()
                }
            case _ => ()
        }
    }

    // TODO : Fix by removing the "as"/"is", add Effect handlers for ThisSuperReference and 
    // function call check
    public override func visit(callExpr: CallExprWithRef) {
        callExpr.arguments.iterator().forEach({ arg => 
            arg.traverse(this)
        })

        match (callExpr.callee as ThisSuperReference) {
            case Some(_) => throw Exception("can not call 'this'/'super' constructor functions")
            case _ => 
                match (callExpr.callee as MemberAccessWithRef) {
                    case Some(memberAccess) => 
                        if (memberAccess.baseExpr is ThisSuperReference) {
                            try {
                                callExpr.ref.getOrThrow().traverse(this)
                            } handle(exactFuncReference: ExactFuncReference) {
                                let funcReference = exactFuncReference.funcReference
                                if (decls.contains(funcReference) && !allClassMembersInitialized) {
                                    throw Exception("Member function ${funcReference.identifier}" + 
                                    " is referenced before all member variables are initialized")
                                }
                                resume with ()
                            }
                        }
                    case _ => ()
                }
        }

        callExpr.callee.traverse(this)
    }

    public override func visit(_: ThisSuperReference){
        if (!allClassMembersInitialized) {
            throw Exception("Can not reference this/super before initialization of member " + 
            "variables")
        }
    }

    private func visitConstructorBlock(block: Block) {
        // TODO : Can we remove use of "as" here and make the code better?
        // I believe it is possible to remove "as" here using effect handlers. Figure out the best
        // way to implement it
        // TODO : Also need to check if super() is called explicitly, and it not, check if super 
        // class contains default constructor
        match (block.nodes.get(0)) {
            case Some(node) => 
                match (node as CallExprWithRef) {
                    case Some(callExpr) => 
                        match (callExpr.callee as ThisSuperReference) {
                            case Some(thisSuperReference) => 
                                block.nodes.remove(at: 0)
                                tryVisitConstructor(callExpr.ref.getOrThrow())
                            case _ => ()
                        }
                    case _ => ()
                }
            case _ => ()
        }

        beginScope(perform InferBlockType())
        superIsInitialized = true

        while (let Some(paramReference) <- perform ParameterDeclaration()) {
                declare(paramReference)
                initialize(paramReference)
        }

        try {
            block.nodes.iterator().forEach({ node => 
                node.traverse(this)
            })
        } handle(_: InferBlockType) {
            resume with ScopeType.BLOCK
        } handle(ifElseInit: IfElseInitialization<Reference, Int64>) {
            let initialized = ifElseInit.branchInitializations.elements.iterator().fold(
                ArrayList<Reference>(), { acc, entry => 
                    acc.add(entry[0])
                    acc
                })

            initialize(initialized)
            resume with ()
        } handle(exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception("Variable ${exactVarReference.varReference.identifier} is" + 
                "referenced before initialization in reference " + 
                "${exactVarReference.locationRef.getOrThrow().value}")
                // The position of this reference is stored at the position of the token 
                // refIdentifier
            }
            resume with ()
        } handle(_: MemberVarReference) {
            resume with ()
        }

        endScope()
    }

    private func visitConstructor(initDecl: FuncDeclWithRef) {
        let storedInitializedMemberVariables = initializedMemberVariables

        if (let Some(declType) <- initDecl.declType) {
            declType.traverse(this)
        }

        let paramRef = Utils.foldToStack(initDecl.funcRef.paramRef.getOrDefault({ 
            => ArrayList<VariableReference>()}).iterator(), ArrayStack<VariableReference>())
        try {
            visitConstructorBlock(initDecl.block)
        } handle(_: ParameterDeclaration) {
            resume with paramRef.remove()
        } handle(_: InferBlockType) {
            resume with ScopeType.BLOCK
        }

        if (!allClassMembersInitialized) {
            throw Exception("Constructor function does not" + 
            " initialize all variables")
        }
        initializedMemberVariables = storedInitializedMemberVariables
    }

    protected func tryVisitConstructor(funcReference: Reference): Unit{ 
        match (unvisitedConstructors.get(funcReference)) {
            case Some(constructor) => 
                unvisitedConstructors.remove(funcReference)
                currentPathConstructors.add(funcReference)
                visitConstructor(constructor)
            case _ => 
                if (currentPathConstructors.contains(funcReference)) {
                    throw Exception("Constructor functions can not form a cycle")
                }
        }
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

    protected override func isInitialized(reference: Reference): Bool {
        if (decls.contains(reference)) {
            allClassMembersInitialized || initializeEnvironment.getGlobal(reference).isSome()
        } else if (
            let Some(ref) <- accessibleMembers.getMembersReference(reference.identifier.value) &&
            ref == reference
        ) {
            superIsInitialized
        } else {
            initializeEnvironment.getGlobal(reference).isSome()
        }
    }

    private prop allClassMembersInitialized: Bool {
        get() { totalMemberVariables == initializedMemberVariables }
    }
}

/*

TODO : In the future, For static variables similar check can be done probably

*/

public class StaticGlobalVariableInitializationChecker <: DefaultVisitor<Unit> {
    private let unvisitedFunctions = Environment<Reference, FuncDeclWithRef>()
    private let uninitializedVariables = HashSet<Reference>()

    public init(program: Program) {
        super(())
        program.decls.iterator().forEach({ decl => process(decl) })

        program.traverse(this)
    }

    public override func visit(program: Program) {
        program.decls.iterator().forEach({ decl => 
            tryVisit(decl)
        })
    }

    public override func visit(callExpr: CallExprWithRef) {
        callExpr.arguments.iterator().forEach({ arg => 
            arg.traverse(this)
        })

        tryVisit(callExpr.ref.getOrThrow())
        callExpr.callee.traverse(this)
    }

    public override func visit(funcDecl: FuncDeclWithRef) {
        unvisitedFunctions.destroy(funcDecl.funcRef)
        if (let Some(declType) <- funcDecl.declType) {
            declType.traverse(this)
        }

        funcDecl.block.traverse(this)
    }

    public override func visit(varDecl: VarDeclWithRef) {
        if (let Some(initzer) <- varDecl.initializer) {
            initzer.traverse(this)
        }

        if (let Some(declType) <- varDecl.declType) {
            declType.traverse(this)
        }

        initializeVariable(varDecl)
    }

    public override func visit(body: Body) {
        body.decls.iterator().forEach({ decl => 
            tryVisit(decl)
        })
    }

    public override func visit(refExpr: RefExprWithRef) {
        try { 
            refExpr.ref.getOrThrow().traverse(this)
        } handle(exactVarReference: ExactVarReference) {
            let varReference = exactVarReference.varReference

            if (!isInitialized(varReference)) {
                throw Exception("Use of static/global variable ${varReference.identifier.value}" + 
                " before initialization")
            }
            resume with ()
        }
    }

    public override func visit(varReference: VariableReference) {
        perform ExactVarReference(varReference)
    }

    public override func visit(funcReference: FuncReference) {
        tryVisit(funcReference)
    }

    private func initializeVariable(varDecl: VarDeclWithRef): Unit {
        uninitializedVariables.remove(varDecl.ref)
    }

    private func isInitialized(reference: Reference) {
        !uninitializedVariables.contains(reference)
    }

    private func declareVariable(varDecl: VarDeclWithRef) {
        uninitializedVariables.add(varDecl.ref)
    }

    private func declareFunction(funcDecl: FuncDeclWithRef) {
        if (unvisitedFunctions.getLocal(funcDecl.funcRef).isNone()) {
            unvisitedFunctions.declare(funcDecl.funcRef, funcDecl)
        }
    }

    // TODO : Can we remove "as" and make the code of the following better?
    // I believe the removal of "as"/"is" here will not result in "better" code. They do not cause 
    // a lot of harm. Hence, I think it is okay to leave them here
    private func process(decl: Decl): Unit {
        if (let Some(funcDecl) <- (decl as FuncDeclWithRef)) {
            declareFunction(funcDecl)
        } else if (let Some(classDecl) <- (decl as ClassDeclWithRef)) {
            classDecl.body.decls.iterator().forEach({ decl => process(decl) })
        } else if (let Some(varDecl) <- (decl as VarDeclWithRef)) {
            declareVariable(varDecl)
        }
    }

    private func tryVisit(decl: Decl) {
        match (decl as FuncDeclWithRef) {
            case Some(funcDecl) => tryVisit(funcDecl.funcRef)
            case _ => decl.traverse(this)
        }
    }

    private func tryVisit(funcRef: FuncReference) {
        match (unvisitedFunctions.getLocal(funcRef)) {
            case Some(funcDecl) => funcDecl.traverse(this)
            case _ => ()
        }
    }
}
