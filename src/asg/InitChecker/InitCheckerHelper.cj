package cjcj.asg.InitChecker

import cjcj.visitor.*
import std.env.getStdOut
import std.collection.HashSet
import std.collection.HashMap
import std.collection.ArrayList
import std.deriving.Derive

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

