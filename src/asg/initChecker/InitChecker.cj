package cjcj.asg.initChecker

import cjcj.asg.Utils
import cjcj.visitor.*
import cjcj.scanner.*
import cjcj.asg.typeChecker.MembersContainer
import cjcj.parser.NodeIdManager
import std.collection.HashSet
import std.collection.ArrayList
import std.collection.ArrayStack
import std.ast.Position

public open class InitChecker <: DefaultVisitor<Unit> {
    protected var environments: InitCheckerEnvironments
    protected var lastKilledEnvironment: InitCheckerEnvironments

    public init(environments_: InitCheckerEnvironments) {
        super(())
        environments = environments_
        lastKilledEnvironment = environments
    }

    public init(classMembersContainer: Environment<String, MembersContainer>) {
        super(())
        environments = InitCheckerEnvironments(classMembersContainer)
        lastKilledEnvironment = environments
    }

    public init(initChecker: InitChecker) {
        super(())
        environments = initChecker.environments
        lastKilledEnvironment = initChecker.lastKilledEnvironment
    }

    public func resolve(program: Program) {
        try {
            program.traverse(this)
        } handle (exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception(
                    "Variable ${exactVarReference.varReference.identifier} is" +
                        "referenced before initialization in reference " +
                        "${exactVarReference.locationRef.getOrThrow().value}")
                // The position of this reference is stored at the position of the token 
                // refIdentifier
            }
            resume with ()
        } handle (_: MemberVarReference) {
            resume with ()
        }

        StaticGlobalVariableInitializationChecker(program)
    }

    public open override func visit(assignExpr: AssignExpr) {
        assignExpr.right.traverse(this)

        try {
            assignExpr.left.traverse(this)
        } handle (exactVarReference: ExactVarReference) {
            let varReference = exactVarReference.varReference

            if (!maybeInitialized(varReference)) {
                initialize(varReference)
            } else if (varReference.keyword.kind == TokenKind.LET) {
                throw Exception("Mutation of immutable variable" + " ${varReference.identifier.value}")
            }
            resume with ()
        } handle (memberVarReference: MemberVarReference) {
            let varReference = memberVarReference.varReference

            if (varReference.keyword.kind == TokenKind.LET) {
                throw Exception("Mutation of immutable member variable" + " ${varReference.identifier.value}")
            }
            resume with ()
        }
        // For error reporting use the locationRef in MemberVarReference or ExactVarReference
    }

    public open override func visit(varReference: VariableReference) {
        perform ExactVarReference(varReference)
    }

    public open override func visit(refExpr: RefExprWithRef) {
        try {
            refExpr.ref.traverse(this)
        } handle (exactVarReference: ExactVarReference) {
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
            block.nodes.iterator().forEach({
                node => node.traverse(this)
            })
        } handle (_: InferBlockType) {
            throw Exception("Block has no proper (ifElse, funcDecl, whileExpr) parent node")
        } handle (ifElseInit: IfElseInitialization) {
            ifElseInit.branchInitializations.definiteInitializeEnvironment.elements.iterator().forEach(
                {
                    entry =>
                        let (ref, _) = entry
                        initialize(ref)
                }
            )

            ifElseInit.branchInitializations.possibleInitializeEnvironment.elements.iterator().forEach(
                {
                    entry =>
                        let (ref, _) = entry
                        if (isDeclared(ref)) {
                            possibleInitialize(ref)
                        }
                }
            )
            resume with ()
        } handle (exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception(
                    "Variable ${exactVarReference.varReference.identifier} is" +
                        "referenced before initialization in reference " +
                        "${exactVarReference.locationRef.getOrThrow().value}")
                // The position of this reference is stored at the position of the token 
                // refIdentifier
            }
            resume with ()
        } handle (_: MemberVarReference) {
            resume with ()
        }

        endScope()
    }

    public override func visit(ifExpr: IfExpr) {
        try {
            ifExpr.elseBranch.traverse(this)
        } handle (_: IfElseInitialization) {
            resume with ()
        } handle (_: InferBlockType) {
            resume with ScopeType.IFBLOCK
        }

        let elseBranchInitializeEnvironment = lastKilledEnvironment

        ifExpr.condition.traverse(this)
        try {
            ifExpr.ifBlock.traverse(this)
        } handle (_: InferBlockType) {
            resume with ScopeType.IFBLOCK
        }

        merge(lastKilledEnvironment, elseBranchInitializeEnvironment)
        perform IfElseInitialization(lastKilledEnvironment)
    }

    public override func visit(whileExpr: WhileExpr) {
        try {
            whileExpr.block.traverse(this)
        } handle (_: InferBlockType) {
            resume with ScopeType.WHILEBLOCK
        }

        whileExpr.condition.traverse(this)
    }

    public open override func visit(callExpr: CallExprWithRef) {
        callExpr.arguments.iterator().forEach({
            arg => arg.traverse(this)
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
            => ArrayList<VariableReference>()
        }).iterator(), ArrayStack<VariableReference>())
        try {
            if (let Some(realBlock) <- funcDecl.block) {
                realBlock.traverse(this)
            }
        } handle (_: ParameterDeclaration) {
            resume with paramRef.remove()
        } handle (_: InferBlockType) {
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

        try {
            mainDecl.block.traverse(this)
        } handle (_: ParameterDeclaration) {
            resume with paramRef.remove()
        } handle (_: InferBlockType) {
            resume with ScopeType.FUNCBLOCK
        }
    }

    public open override func visit(classDecl: ClassDeclWithRef): Unit {
        ClassInitChecker(this, classDecl)
    }

    public open override func visit(memberAccess: MemberAccessWithRef): Unit {
        try {
            memberAccess.baseExpr.traverse(this)
        } handle (exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception(
                    "Variable ${exactVarReference.varReference.identifier} is" +
                        "referenced before initialization in reference " +
                        "${exactVarReference.locationRef.getOrThrow().value}")
            }
            resume with ()
        } handle (_: MemberVarReference) {
            resume with ()
        }

        match (environments
            .classMembersContainer
            .getGlobal(memberAccess.ref.getOrThrow().identifier.value)
            .getOrThrow()
            .getVariableMembersReference(memberAccess.field.value)) {
            case Some(ref) => try {
                ref.traverse(this)
            } handle (exactVarReference: ExactVarReference) {
                perform MemberVarReference(exactVarReference.varReference, memberAccess.field)
                resume with ()
            }
            case _ => ()
        }
    }

    public open override func visit(interfaceDecl: InterfaceDeclWithRef): Unit {
        interfaceDecl.superTypes.iterator().forEach({
            superType => superType.traverse(this)
        })

        interfaceDecl.body.traverse(this)
    }

    public open override func visit(body: Body): Unit {
        body.decls.iterator().forEach({
            decl => decl.traverse(this)
        })
    }

    protected open func beginScope(newScopeType: ScopeType) {
        environments = InitCheckerEnvironments(environments, newScopeType)
    }

    protected open func endScope(): Unit {
        lastKilledEnvironment = environments
        environments = environments.enclosing.getOrThrow({
            => Exception("Trying to close the global scope")
        })
    }

    protected open func declare(reference: VariableReference) {
        environments.declare(reference)
    }

    protected open func isDeclared(reference: VariableReference) {
        environments.isDeclared(reference)
    }

    protected open func initialize(reference: VariableReference) {
        environments.initialize(reference)
    }

    protected open func isInitialized(reference: VariableReference) {
        environments.isInitialized(reference)
    }

    protected open func possibleInitialize(reference: VariableReference) {
        environments.possibleInitialize(reference)
    }

    protected open func maybeInitialized(reference: VariableReference) {
        environments.maybeInitialized(reference)
    }

    protected func merge(left: InitCheckerEnvironments, right: InitCheckerEnvironments) {
        let definiteInits = left.definiteInitializeEnvironment.elements.toArray()

        definiteInits.iterator().forEach(
            {
                entry =>
                    let (ref, _) = entry

                    if (!right.isInitialized(ref)) {
                        left.definiteInitializeEnvironment.destroy(ref)
                    }
            }
        )

        right.possibleInitializeEnvironment.elements.iterator().forEach(
            {
                entry =>
                    let (ref, _) = entry

                    if (!left.maybeInitialized(ref) && left.isDeclared(ref)) {
                        left.possibleInitialize(ref)
                    }
            }
        )
    }
}

private class ClassInitChecker <: InitChecker {
    protected let classEnvironments: ClassInitCheckerEnvironments

    init(
        initChecker: InitChecker,
        classDecl: ClassDeclWithRef
    ) {
        super(initChecker)
        classEnvironments = ClassInitCheckerEnvironments(environments, classDecl)

        classDecl.traverse(this)
    }

    public override func visit(classDecl: ClassDeclWithRef): Unit {
        classDecl.superTypes.iterator().forEach({
            superType => superType.traverse(this)
        })

        classDecl.body.traverse(this)
    }

    public override func visit(body: Body) {
        beginScope(ScopeType.BODY)

        let (varDecls, initDecls, funcDecls) = classEnvironments.bodyPreprocess(body)

        varDecls.forEach({varDecl => varDecl.traverse(this)})

        classEnvironments.superIsInitialized = true
        initDecls.forEach({initDecl => tryVisitConstructor(initDecl.funcRef)})

        classEnvironments.finishInitialization()
        funcDecls.forEach({funcDecl => funcDecl.traverse(this)})

        endScope()
    }

    public override func visit(funcReference: FuncReference) {
        perform ExactFuncReference(funcReference)
    }

    public override func visit(refExpr: RefExprWithRef) {
        try {
            refExpr.ref.traverse(this)
        } handle (exactVarReference: ExactVarReference) {
            exactVarReference.locationRef = refExpr.identifier
            perform exactVarReference

            resume with ()
        } handle (exactFuncReference: ExactFuncReference) {
            let funcReference = exactFuncReference.funcReference
            if (classEnvironments.isFunctionMember(funcReference) && !allClassMembersInitialized) {
                throw Exception(
                    "Member function ${funcReference.identifier} is referenced before" +
                        " all member variables are initialized")
            }
            resume with ()
        }
    }

    public override func visit(memberAccess: MemberAccessWithRef) {
        try {
            memberAccess.baseExpr.traverse(this)
        } handle (exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception(
                    "Variable ${exactVarReference.varReference.identifier} is" +
                        "referenced before initialization in reference " +
                        "${exactVarReference.locationRef.getOrThrow().value}")
            }
            resume with ()
        } handle (_: MemberVarReference) {
            resume with ()
        }

        match (environments
            .classMembersContainer
            .getGlobal(memberAccess.ref.getOrThrow().identifier.value)
            .getOrThrow()
            .getVariableMembersReference(memberAccess.field.value)) {
            case Some(ref) => try {
                ref.traverse(this)
            } handle (exactVarReference: ExactVarReference) {
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

    public override func visit(callExpr: CallExprWithRef) {
        callExpr.arguments.iterator().forEach({
            arg => arg.traverse(this)
        })

        match (callExpr.callee as ThisSuperReference) {
            case Some(_) => throw Exception("can not call 'this'/'super' constructor functions")
            case _ => match (callExpr.callee as MemberAccessWithRef) {
                case Some(memberAccess) =>
                    if (memberAccess.baseExpr is ThisSuperReference) {
                        try {
                            callExpr.ref.getOrThrow().traverse(this)
                        } handle (exactFuncReference: ExactFuncReference) {
                            let funcReference = exactFuncReference.funcReference
                            if (classEnvironments.isFunctionMember(funcReference) && !allClassMembersInitialized) {
                                throw Exception(
                                    "Member function ${funcReference.identifier}" +
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

    public override func visit(_: ThisSuperReference) {
        if (!allClassMembersInitialized) {
            throw Exception("Can not reference this/super before initialization of member " + "variables")
        }
    }

    private func visitConstructorBlock(block: Block) {
        var superIsCalled: Bool = false
        match (block.nodes.get(0)) {
            case Some(node) => match (node as CallExprWithRef) {
                case Some(callExpr) => match (callExpr.callee as ThisSuperReference) {
                    case Some(thisSuperReference) =>
                        block.nodes.remove(at: 0)
                        tryVisitConstructor(callExpr.ref.getOrThrow())
                        superIsCalled = true
                    case _ => ()
                }
                case _ => ()
            }
            case _ => ()
        }

        // If super() is not called explicitly, check if super class contains default constructor
        if (!superIsCalled && let Some(superClass) <- classEnvironments.accessibleMembers.superClass &&
            !superClass.typeManager.getOrThrow().exactFuncExists(
            FuncReference(
                NodeIdManager.nextId(),
                Token(TokenKind.ILLEGAL, "", Position()),
                ArrayList<VariableReference>()
            )
        )) {
            throw Exception(
                "Super class ${superClass.typeReference.identifier} of the class " +
                    "${classEnvironments.accessibleMembers.typeReference.identifier} does not have a " +
                    "default constructor and constructor is not called explicitly!")
        }

        beginScope(perform InferBlockType())

        while (let Some(paramReference) <- perform ParameterDeclaration()) {
            declare(paramReference)
            initialize(paramReference)
        }

        try {
            block.nodes.iterator().forEach({
                node => node.traverse(this)
            })
        } handle (_: InferBlockType) {
            throw Exception("Block has no proper (ifElse, funcDecl, whileExpr) parent node")
        } handle (ifElseInit: IfElseInitialization) {
            ifElseInit.branchInitializations.definiteInitializeEnvironment.elements.iterator().forEach(
                {
                    entry =>
                        let (ref, _) = entry
                        initialize(ref)
                }
            )

            ifElseInit.branchInitializations.possibleInitializeEnvironment.elements.iterator().forEach(
                {
                    entry =>
                        let (ref, _) = entry
                        possibleInitialize(ref)
                }
            )
            resume with ()
        } handle (exactVarReference: ExactVarReference) {
            if (!isInitialized(exactVarReference.varReference)) {
                throw Exception(
                    "Variable ${exactVarReference.varReference.identifier} is" +
                        "referenced before initialization in reference " +
                        "${exactVarReference.locationRef.getOrThrow().value}")
                // The position of this reference is stored at the position of the token 
                // refIdentifier
            }
            resume with ()
        } handle (_: MemberVarReference) {
            resume with ()
        }

        if (!allClassMembersInitialized) {
            throw Exception("Constructor function does not" + " initialize all variables")
        }

        endScope()
    }

    private func visitConstructor(initDecl: FuncDeclWithRef) {
        if (let Some(declType) <- initDecl.declType) {
            declType.traverse(this)
        }

        let paramRef = Utils.foldToStack(initDecl.funcRef.paramRef.getOrDefault({
            => ArrayList<VariableReference>()
        }).iterator(), ArrayStack<VariableReference>())
        try {
            visitConstructorBlock(initDecl.block.getOrThrow({
                => Exception("Constructor function must have a block")
            }))
        } handle (_: ParameterDeclaration) {
            resume with paramRef.remove()
        } handle (_: InferBlockType) {
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
        lastKilledEnvironment = environments
        environments = environments.enclosing.getOrThrow({
            => Exception("Trying to close the global scope")
        })
        classEnvironments.endScope(environments)
    }

    protected override func initialize(reference: VariableReference) {
        classEnvironments.initialize(reference)
    }

    protected override func isInitialized(reference: VariableReference): Bool {
        classEnvironments.isInitialized(reference)
    }

    protected override func possibleInitialize(reference: VariableReference) {
        classEnvironments.possibleInitialize(reference)
    }

    protected override func maybeInitialized(reference: VariableReference): Bool {
        classEnvironments.maybeInitialized(reference)
    }

    private prop allClassMembersInitialized: Bool {
        get() {
            classEnvironments.allClassMembersInitialized
        }
    }
}

public class StaticGlobalVariableInitializationChecker <: DefaultVisitor<Unit> {
    private let unvisitedFunctions = Environment<Reference, FuncDeclWithRef>()
    private let uninitializedVariables = HashSet<Reference>()

    public init(program: Program) {
        super(())
        program.decls.iterator().forEach({decl => process(decl)})

        program.traverse(this)
    }

    public override func visit(program: Program) {
        program.decls.iterator().forEach({
            decl => tryVisit(decl)
        })
    }

    public override func visit(callExpr: CallExprWithRef) {
        callExpr.arguments.iterator().forEach({
            arg => arg.traverse(this)
        })

        tryVisit(callExpr.ref.getOrThrow())
        callExpr.callee.traverse(this)
    }

    public override func visit(funcDecl: FuncDeclWithRef) {
        unvisitedFunctions.destroy(funcDecl.funcRef)
        if (let Some(declType) <- funcDecl.declType) {
            declType.traverse(this)
        }

        if (let Some(realBlock) <- funcDecl.block) {
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
        body.decls.iterator().forEach({
            decl => tryVisit(decl)
        })
    }

    public override func visit(refExpr: RefExprWithRef) {
        try {
            refExpr.ref.traverse(this)
        } handle (exactVarReference: ExactVarReference) {
            let varReference = exactVarReference.varReference

            if (!isInitialized(varReference)) {
                throw Exception(
                    "Use of static/global variable ${varReference.identifier.value}" + " before initialization")
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

    private func process(decl: Decl): Unit {
        if (let Some(funcDecl) <- (decl as FuncDeclWithRef)) {
            declareFunction(funcDecl)
        } else if (let Some(classDecl) <- (decl as ClassDeclWithRef)) {
            classDecl.body.decls.iterator().forEach({decl => process(decl)})
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
