package cjcj.asg.initChecker

import cjcj.visitor.*
import cjcj.scanner.*
import cjcj.asg.typeChecker.MembersContainer
import std.collection.ArrayList
import std.collection.HashSet
import std.collection.HashMap
import std.deriving.Derive
import stdx.effect.Command

/* Effects */
public class ParameterDeclaration <: Command<Option<VariableReference>> {
}

public class InferBlockType <: Command<ScopeType> {
}

public class IfElseInitialization <: Command<Unit> {
    private let branchInitializations_: InitCheckerEnvironments

    init(branchInitializations: InitCheckerEnvironments) {
        branchInitializations_ = branchInitializations
    }

    public prop branchInitializations: InitCheckerEnvironments {
        get() { branchInitializations_ }
    }
}

public class ExactVarReference <: Command<Unit> {
    ExactVarReference(public let varReference: VariableReference, public var locationRef: ?Token) {}
    init(varReference_: VariableReference) {
        varReference = varReference_
        locationRef = None
    }
}

public class MemberVarReference <: Command<Unit> {
    MemberVarReference(public let varReference: VariableReference, public var locationRef: Token){}
}

public class ExactFuncReference <: Command<Unit> {
    ExactFuncReference(public let funcReference: FuncReference) {}
}


/* Extensions and Utilized Tools */

extend<K, V> Environment<K, V> where K <: Hashable & Equatable<K> & ToString {
    public func destroy(key: K): Unit {
        elements.remove(key)
    }
}

func swapToMin<T, K>(a: T, b: T) where T <: Collection<K> {
    if(a.size > b.size) {
        (b, a)
    } else {
        (a, b)
    }
}

@Derive[Equatable]
public enum ScopeType {
    NIL | IFBLOCK | BODY | FUNCBLOCK | WHILEBLOCK
}

public class SingularEnvironment<T> {
    var current_: T
    let enclosing_: ?SingularEnvironment<T>

    init(enclosing: SingularEnvironment<T>) {
        enclosing_ = enclosing
        current_ = enclosing.current
    }

    init(storedInfo: T, enclosing: ?SingularEnvironment<T>) {
        current_ = storedInfo
        enclosing_ = enclosing
    }

    init(storedInfo: T){
        current_ = storedInfo
        enclosing_ = None
    }

    public prop enclosing: ?SingularEnvironment<T> {
        get() { enclosing_ }
    }
    
    public prop isGlobal: Bool {
        get() { enclosing_.isNone() }
    }

    public mut prop current: T {
        get() { current_ }
        set(v) { current_ = v }
    }
}

open public class InitCheckerEnvironments{
    protected var declareEnvironment = Environment<VariableReference, Int64>()
    protected var definiteInitializeEnvironment = Environment<VariableReference, Int64>()
    protected var possibleInitializeEnvironment = Environment<VariableReference, Int64>()
    protected var currentScopeType: SingularEnvironment<ScopeType> = 
        SingularEnvironment<ScopeType>(ScopeType.NIL)
    protected var classMembersContainer: Environment<String, MembersContainer>
    protected var enclosing: ?InitCheckerEnvironments

    public init(environments: InitCheckerEnvironments) {
        declareEnvironment = environments.declareEnvironment
        definiteInitializeEnvironment = environments.definiteInitializeEnvironment
        possibleInitializeEnvironment = environments.possibleInitializeEnvironment
        currentScopeType = environments.currentScopeType
        classMembersContainer = environments.classMembersContainer
        enclosing = None
    }

    public init(environments: InitCheckerEnvironments, newScopeType: ScopeType) {
        this(
            environments.declareEnvironment, 
            environments.definiteInitializeEnvironment, 
            environments.possibleInitializeEnvironment, 
            environments.currentScopeType, newScopeType, 
            environments.classMembersContainer, 
            environments
        )
    }

    public init(
        declareEnvironment_: Environment<VariableReference, Int64>, 
        definiteInitializeEnvironment_: Environment<VariableReference, Int64>,
        possibleInitializeEnvironment_: Environment<VariableReference, Int64>,
        currentScopeType_: SingularEnvironment<ScopeType>, newScopeType: ScopeType,
        classMembersContainer_: Environment<String, MembersContainer>, 
        enclosing_: ?InitCheckerEnvironments
    ){
        declareEnvironment = Environment(declareEnvironment_) 
        definiteInitializeEnvironment = Environment(definiteInitializeEnvironment_) 
        possibleInitializeEnvironment = Environment(possibleInitializeEnvironment_)
        currentScopeType = SingularEnvironment<ScopeType>(newScopeType, currentScopeType_) 
        classMembersContainer = classMembersContainer_
        enclosing = enclosing_
    }
    
    public init(classMembersContainer_: Environment<String, MembersContainer>) {
        classMembersContainer = classMembersContainer_
        enclosing = None
    }

    protected open func declare(reference: VariableReference) {
        declareEnvironment.declare(reference, 0)
    }

    protected open func canCapture(reference: VariableReference) :Bool { 
        var declEnvironment = declareEnvironment
        var scopeType = currentScopeType

        while (!declEnvironment.isGlobal && !scopeType.isGlobal) {
            if (declEnvironment.getLocal(reference).isSome()) {
                return true;
            } else if (scopeType.current == ScopeType.FUNCBLOCK || 
                        (scopeType.current == ScopeType.WHILEBLOCK && 
                        reference.keyword.kind == TokenKind.LET)) {
                return false;
            }
            declEnvironment = declEnvironment.enclosing.getOrThrow()
            scopeType = scopeType.enclosing.getOrThrow()
        }

        true
    }

    protected open func initialize(reference: VariableReference) {
        possibleInitialize(reference)
        if (!isInitialized(reference)) {
            if (!canCapture(reference)) {
                throw Exception("Cannot capture variable ${reference.identifier.value} before " + 
                "initialization")
            }
            definiteInitializeEnvironment.declare(reference, 0)
        }
    }

    protected open func isInitialized(reference: VariableReference) {
        definiteInitializeEnvironment.getGlobal(reference).isSome()
    }

    protected open func possibleInitialize(reference: VariableReference) {
        if (!maybeInitialized(reference)) {
            if (!canCapture(reference)) {
                throw Exception("Cannot capture variable ${reference.identifier.value} before " + 
                "initialization")
            }
            possibleInitializeEnvironment.declare(reference, 0)
        }
    }

    protected open func maybeInitialized(reference: VariableReference) {
        possibleInitializeEnvironment.getGlobal(reference).isSome()
    }

    // protected func intersect<K, V> (left: Environment<K, V>, right: Environment<K, V>) where K <: 
    //         Hashable & Equatable<K> & ToString {
    //     let leftElementsArr = left.elements.toArray()
    //     leftElementsArr.iterator().forEach({ entry => 
    //         let (key, _) = entry
    //         if (right.getLocal(key).isNone()){
    //             left.destroy(key)
    //         }
    //     })
    // }

    // protected func merge<K, V> (left: Environment<K, V>, right: Environment<K, V>) where K <: 
    //         Hashable & Equatable<K> & ToString {
    //     let rightElementsArr = right.elements.toArray()
    //     rightElementsArr.iterator().forEach({ entry => 
    //         let (key, val) = entry
    //         left.declare(key, val)
    //     })
    // }
}

public class ClassInitCheckerEnvironments <: InitCheckerEnvironments {
    protected var initializedMemberVariables = SingularEnvironment<Int64>(0)
    protected var environments: InitCheckerEnvironments
    protected var superIsInitialized: Bool = false

    /* Global objects, which are used do not change throughtout the processing of class */
    protected var totalMemberVariables: Int64 = 0
    protected var accessibleMembers: MembersContainer
    protected var decls: HashSet<Reference> = HashSet<Reference>()

    protected let unvisitedConstructors = HashMap<Reference, FuncDeclWithRef>()
    protected let currentPathConstructors = HashSet<Reference>()

    init(environments: InitCheckerEnvironments, classDecl: ClassDeclWithRef) {
        super(environments)
        this.environments = environments

        accessibleMembers = environments.classMembersContainer
        .getGlobal(classDecl.identifier.value).getOrThrow({ => 
            Exception("Can not find the class ${classDecl.identifier.value} in class Member" + 
            " Containers")
        })
    }

    // TODO : cleanup the bodyPreprocessor
    // I need to think if this can be improved without use of a new visitor
    // Currently I believe that this is not possible, but maybe we can use effect handlers for this
    protected func bodyPreprocess(body: Body) {
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
            if(let Some(funcDecl) <- (decl as FuncDeclWithRef) && funcDecl.keyword.value == "init"){
                acc.add(funcDecl)
            }
            acc
        })
        let funcDecls = body.decls.iterator().filter({decl => 
            if(let Some(funcDecl) <- (decl as FuncDeclWithRef) && funcDecl.keyword.value != "init"){
                true
            } else { false }
        })

        initDecls.iterator().forEach({ initDecl => 
            unvisitedConstructors.add(initDecl.funcRef, initDecl) })

        (varDecls, initDecls.iterator(), funcDecls)
    }

    protected func finishInitialization() {
        initializedMemberVariables.current = totalMemberVariables
    }

    protected func tryVisitConstructor(funcReference: Reference): ?FuncDeclWithRef{ 
        match (unvisitedConstructors.get(funcReference)) {
            case Some(constructor) => 
                unvisitedConstructors.remove(funcReference)
                currentPathConstructors.add(funcReference)
                constructor
            case _ => 
                if (currentPathConstructors.contains(funcReference)) {
                    throw Exception("Constructor functions can not form a cycle")
                }
                None
        }
    }

    protected func beginScope(newEnvironments: InitCheckerEnvironments) {
        environments = newEnvironments
        initializedMemberVariables = SingularEnvironment(initializedMemberVariables)
    }

    protected func endScope(newEnvironments: InitCheckerEnvironments) {
        environments = newEnvironments
        initializedMemberVariables = initializedMemberVariables.enclosing.getOrThrow({ => 
            Exception("Trying to close the global scope") })
    }

    protected override func initialize(reference: VariableReference) {
        possibleInitialize(reference)
        if (!isInitialized(reference)) {
            if (decls.contains(reference)) {
                initializedMemberVariables.current++
            } else if (!canCapture(reference)) {
                throw Exception("Cannot capture variable ${reference.identifier.value} before " + 
                "initialization")
            }
            environments.definiteInitializeEnvironment.declare(reference, 0)
        }
    }

    protected override func isInitialized(reference: VariableReference): Bool {
        if (decls.contains(reference)) {
            allClassMembersInitialized || 
            environments.definiteInitializeEnvironment.getGlobal(reference).isSome()
        } else if (
            let Some(ref) <- accessibleMembers.getMembersReference(reference.identifier.value) &&
            ref == reference
        ) {
            superIsInitialized
        } else {
            environments.definiteInitializeEnvironment.getGlobal(reference).isSome()
        }
    }

    protected override func possibleInitialize(reference: VariableReference) {
        if (!maybeInitialized(reference)) {
            if (!decls.contains(reference) && !canCapture(reference)) {
                throw Exception("Cannot capture variable ${reference.identifier.value} before " + 
                "initialization")
            }

            environments.possibleInitializeEnvironment.declare(reference, 0)
        }
    }

    protected override func maybeInitialized(reference: VariableReference): Bool {
        if(decls.contains(reference)) {
            allClassMembersInitialized || 
            environments.possibleInitializeEnvironment.getGlobal(reference).isSome()
        } else if (
            let Some(ref) <- accessibleMembers.getMembersReference(reference.identifier.value) && 
            ref == reference
        ) {
            superIsInitialized
        } else {
            environments.possibleInitializeEnvironment.getGlobal(reference).isSome()
        }
    }

    protected prop allClassMembersInitialized: Bool {
        get() { totalMemberVariables == initializedMemberVariables.current }
    }

    protected func isMember(ref: Reference) {
        decls.contains(ref)
    }
}