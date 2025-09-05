package cjcj.visitor

// import cjcj.parser.NodeIdManager
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
// import cjcj.parser.ParseError

// import cjcj.visitor.*

import std.collection.Map
import std.collection.HashMap
import std.collection.ArrayList
/*
* Defines an Environment in which every identifier has a reference object to
* refer to. Each environment knows who was before him and is able to provide
* identifiers' references by going up the cactus. (From every environment
* there's only one way to the root)
*/
public class Environment {
    private let enclosing_: ?Environment
    private let varReferences: Map<String, Reference> = HashMap()
    private let funcReferences: Map<String, Reference> = HashMap()
    private let classReferences: Map<String, Reference> = HashMap()

    public init(enclosing: ?Environment) {
        enclosing_ = enclosing
    }

    public init() {
        this(None)
    }

    public func get(identifier: Token): Reference {
        if (let Some(value) <- varReferences.get(identifier.value)) {
            return value
        } else if (let Some(value) <- funcReferences.get(identifier.value)) {
            return value
        } else if (let Some(value) <- classReferences.get(identifier.value)) {
            return value
        }

        // Go up the environments until something is found or an exception is
        // thrown. (Recursion is clean but slow this may need optimization)
        if (enclosing.isSome()) {
            return enclosing.getOrThrow().get(identifier)
        }

        throw Exception("Undefined variable '" + identifier.value + "'.")
    }

    public func declareClass(identifier: Token, value: Reference): Unit {
        if(varReferences.contains(identifier.value)) {
            throw Exception("Cannot define a class and a variable wirth the same name in the " + 
                "same scope")
        } else if(funcReferences.contains(identifier.value)) {
            throw Exception("Cannot define a class and a function with the same name in the " + 
                "same scope")
        } else if(classReferences.addIfAbsent(identifier.value, value).isSome()){
            throw Exception("Cannot redefine a class with the same name in the same scope")
        }
    }

    public func declareVar(identifier: Token, value: Reference): Unit {
        if (funcReferences.contains(identifier.value)){
            throw Exception("Cannot define a variable and a function with the" + 
                " same name in the same scope")
        } else if (classReferences.contains(identifier.value)) {
            throw Exception("Cannot define a variable and a class with the" + 
                " same name in the same scope")
        } else if (varReferences.addIfAbsent(identifier.value, value).isSome()) {
            throw Exception("Cannot redefine a variable with the in the same scope")
        }
    }

    public func declareFunc(identifier: Token, value: Reference): Unit {
        if(varReferences.contains(identifier.value)) {
            throw Exception("Cannot define a function and variable with the same name in the " +
                "same scope")
        } else if(classReferences.contains(identifier.value)) {
            throw Exception("Cannot define a function and class with the same name in the " +
                "same scope")
        } else {
            funcReferences.add(identifier.value, value)
        }
    }

    public func isTypeDeclared(typeName: Token) {
        classReferences.contains(typeName.value)
    }

    public prop enclosing: ?Environment {
        get() { enclosing_ }
    }
    public prop isGlobal: Bool {
        get() { return enclosing.isNone() }
    }
}