package cjcj.asg.initChecker

import cjcj.visitor.*
import std.deriving.Derive
import stdx.effect.Command
import cjcj.scanner.Token

public class ParameterDeclaration <: Command<Option<VariableReference>> {
}

public class InferBlockType <: Command<ScopeType> {
}

public class IfElseInitialization<K, V> <: Command<Unit> 
        where K <: Hashable & Equatable<K> & ToString {
    private let branchInitializations_: Environment<K, V>

    init(branchInitializations: Environment<K, V>) {
        branchInitializations_ = branchInitializations
    }
    init() {
        this(Environment<K, V>())
    }

    public prop branchInitializations: Environment<K, V> {
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

extend<K, V> Environment<K, V> where K <: Hashable & Equatable<K> & ToString {
    public func destroy(key: K): Unit {
        elements.remove(key)
    }
}

@Derive[Equatable]
public enum ScopeType {
    NIL | BLOCK | BODY | FUNCBLOCK
}

public class ScopeEnvironment {
    let currentScopeType: ScopeType
    let enclosing_: ?ScopeEnvironment

    init(scopeType: ScopeType, enclosing: ?ScopeEnvironment) {
        currentScopeType = scopeType
        enclosing_ = enclosing
    }

    init(scopeType: ScopeType){
        currentScopeType = scopeType
        enclosing_ = None
    }

    init(){
        currentScopeType = ScopeType.NIL
        enclosing_ = None
    }

    public prop enclosing: ?ScopeEnvironment {
        get() { enclosing_ }
    }
    public prop isGlobal:Bool {
        get() { enclosing_.isNone() }
    }
}
