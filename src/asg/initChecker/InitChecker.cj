package cjcj.asg.initChecker

import cjcj.asg.Utils
import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.asg.typeChecker.ClassReferenceForTC

import std.collection.HashSet
import std.collection.ArrayList
import std.collection.ArrayStack

public open class InitChecker <: DefaultVisitor<Unit> {
    protected var environments: InitCheckerEnvironments
    protected var lastKilledEnvironment = Environment<Reference, Int64>()

    public init(environments_: InitCheckerEnvironments){
        super(())
        environments = environments_
    }

    public init(classMembersContainer: Environment<String, ClassReferenceForTC>) {
        super(())
        environments = InitCheckerEnvironments(classMembersContainer)
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
                " ${varReference.identifier.value}")
            }
            resume with ()
        } handle(memberVarReference: MemberVarReference) {
            let varReference = memberVarReference.varReference

            if (varReference.keyword.kind == TokenKind.LET) {
                throw Exception("Mutation of immutable member variable" + 
                " ${varReference.identifier.value}")
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
            refExpr.ref.traverse(this)
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
            throw Exception("Block has no proper (ifElse, funcDecl, whileExpr) parent node")
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
    // TODO : the new compiler changed the initialization rules in ifExpr, so the merge here 
    // needs to be fixed
    public override func visit(ifExpr: IfExpr) {
        try{
            ifExpr.elseBranch.traverse(this)
        } handle(_: IfElseInitialization<Reference, Int64>) {
            resume with ()
        } handle(_: InferBlockType) {
            resume with ScopeType.IFBLOCK
        }
        let elseBranchInitializeEnvironment = lastKilledEnvironment

        ifExpr.condition.traverse(this)
        try {
            ifExpr.ifBlock.traverse(this)
        } handle(_: InferBlockType) {
            resume with ScopeType.IFBLOCK
        }

        merge(lastKilledEnvironment, elseBranchInitializeEnvironment)
        perform IfElseInitialization(lastKilledEnvironment)
    }

    public override func visit(whileExpr: WhileExpr) {
        try {
            whileExpr.block.traverse(this)
        } handle(_: InferBlockType) {
            resume with ScopeType.WHILEBLOCK
        }

        whileExpr.condition.traverse(this)
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
            if (let Some(realBlock) <- funcDecl.block) {
                realBlock.traverse(this)
            }
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
        ClassInitChecker(environments, classDecl)
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

        match (environments.classMembersContainer.getGlobal(memberAccess.ref.getOrThrow()
            .identifier.value).getOrThrow().getMembersReference(memberAccess.field.value)){
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

    protected open func beginScope(newScopeType: ScopeType) {
        environments = InitCheckerEnvironments(environments, newScopeType)
    }

    protected open func endScope(): Unit {
        lastKilledEnvironment = environments.initializeEnvironment
        environments = environments.enclosing.getOrThrow({ => 
            Exception("Trying to close the global scope")})
    }

    protected open func declare(reference: Reference) {
        environments.declare(reference)
    }

    protected open func canCapture(reference: Reference) :Bool { 
        environments.canCapture(reference)
    }

    protected open func initialize(reference: Reference) {
        environments.initialize(reference)
    }

    protected func initialize(references: ArrayList<Reference>) {
        environments.initialize(references)
    }

    protected open func isInitialized(reference: Reference) {
        environments.isInitialized(reference)
    }

    protected func merge<K, V> (left: Environment<K, V>, right: Environment<K, V>) where K <: 
            Hashable & Equatable<K> & ToString {
        environments.merge(left, right)
    }
}





/*
Extension of the Checker above that checks initialization of a class 
    TODO: Add "this" and fix the member access
*/
private class ClassInitChecker <: InitChecker {
    protected let classEnvironments: ClassInitCheckerEnvironments

    init (
        environments: InitCheckerEnvironments, 
        classDecl: ClassDeclWithRef
    ){
        super(environments)
        classEnvironments = ClassInitCheckerEnvironments(environments, classDecl)

        classDecl.traverse(this)
    }

    public override func visit(classDecl: ClassDeclWithRef) :Unit {
        classDecl.superTypes.iterator().forEach({ superType => 
            superType.traverse(this)
        })

        classDecl.body.traverse(this)
    }

    public override func visit(body: Body) {
        beginScope(ScopeType.BODY)

        let (varDecls, initDecls, funcDecls) = classEnvironments.bodyPreprocess(body)

        varDecls.forEach({ varDecl => varDecl.traverse(this) })

        classEnvironments.superIsInitialized = true
        initDecls.forEach({ initDecl => tryVisitConstructor(initDecl.funcRef) })

        classEnvironments.finishInitialization()
        funcDecls.forEach({ funcDecl => funcDecl.traverse(this) })

        endScope()
    }

    public override func visit(funcReference: FuncReference) {
        perform ExactFuncReference(funcReference)
    }

    public override func visit(refExpr: RefExprWithRef) {
        try {
            refExpr.ref.traverse(this)
        } handle(exactVarReference: ExactVarReference) {
            exactVarReference.locationRef = refExpr.identifier
            perform exactVarReference

            resume with ()
        } handle(exactFuncReference: ExactFuncReference) {
            let funcReference = exactFuncReference.funcReference
            if (classEnvironments.isMember(funcReference) && !allClassMembersInitialized) {
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

        match (environments.classMembersContainer.getGlobal(memberAccess.ref.getOrThrow().
            identifier.value).getOrThrow().getMembersReference(memberAccess.field.value)) {
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
                                if (classEnvironments.isMember(funcReference) && 
                                    !allClassMembersInitialized) {
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
        // TODO : Also need to check if super() is not called explicitly, and it not, check if super
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

        while (let Some(paramReference) <- perform ParameterDeclaration()) {
            declare(paramReference)
            initialize(paramReference)
        }

        try {
            block.nodes.iterator().forEach({ node => 
                node.traverse(this)
            })
        } handle(_: InferBlockType) {
            throw Exception("Block has no proper (ifElse, funcDecl, whileExpr) parent node")
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

        if (!allClassMembersInitialized) {
            throw Exception("Constructor function does not" + 
            " initialize all variables")
        }

        endScope()
    }

    private func visitConstructor(initDecl: FuncDeclWithRef) {
        if (let Some(declType) <- initDecl.declType) {
            declType.traverse(this)
        }

        let paramRef = Utils.foldToStack(initDecl.funcRef.paramRef.getOrDefault({ 
            => ArrayList<VariableReference>()}).iterator(), ArrayStack<VariableReference>())
        try {
            visitConstructorBlock(initDecl.block.getOrThrow({ => 
                Exception("Constructor function must have a block")}))
        } handle(_: ParameterDeclaration) {
            resume with paramRef.remove()
        } handle(_: InferBlockType) {
            resume with ScopeType.FUNCBLOCK
        }
    }

    protected func tryVisitConstructor(funcReference: Reference): Unit { 
        if (let Some(constructor) <- classEnvironments.tryVisitConstructor(funcReference)) {
            visitConstructor(constructor)
        }
    }

    protected override func beginScope(newScopeType: ScopeType) {
        environments = InitCheckerEnvironments(environments, newScopeType)
        classEnvironments.beginScope(environments)
    }

    protected override func endScope(): Unit {
        lastKilledEnvironment = environments.initializeEnvironment
        environments = environments.enclosing.getOrThrow({ => 
            Exception("Trying to close the global scope") })
        classEnvironments.endScope(environments)
    }

    protected override func initialize(reference: Reference) {
        classEnvironments.initialize(reference)
    }

    protected override func isInitialized(reference: Reference): Bool {
        classEnvironments.isInitialized(reference)
    }

    private prop allClassMembersInitialized: Bool {
        get() { classEnvironments.allClassMembersInitialized }
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

        if (let Some(realBlock) <- funcDecl.block){
            realBlock.traverse(this)
        }
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
            refExpr.ref.traverse(this)
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
