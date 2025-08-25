package cjcj.asg

import cjcj.parser.NodeIdManager
import cjcj.scanner.Token
import cjcj.parser.ParseError

import std.collection.Map
import std.collection.HashMap

/*
* Defines an Environment in which every identifier has a reference object to
* refer to. Each environment knows who was before him and is able to provide
* identifiers' references by going up the cactus. (From every environment
* there's only one way to the root)
*/
class Environment {
    private let enclosing_: ?Environment
    private let values: Map<String, ?Reference> = HashMap()

    init(enclosing: ?Environment) {
        enclosing_ = enclosing
    }

    init() {
        this(None)
    }

    func get(identifier: Token): Reference {
        if (let Some(value) <- values.get(identifier.value)) {
            match (value) {
                case Some(v) => return v
                case None => println("Cannot read uninitialised variable")
                    throw ParseError()
            }
        }

        // Go up the environments until something is found or an exception is
        // thrown. (Recursion is clean but slow this may need optimization)
        if (enclosing.isSome()) {
            return enclosing.getOrThrow().get(identifier)
        }

        println("Undefined variable '" + identifier.value + "'.")
        throw ParseError()
    }

    func assign(identifier: Token, value: Reference): Unit {
        if (values.contains(identifier.value)) {
            values.add(identifier.value, value)
            return
        }

        if (enclosing.isSome()) {
            return enclosing.getOrThrow().assign(identifier, value)
        }
        println("Undefined variable '" + identifier.value + "'.")
        throw ParseError()
    }

    func declare(identifier: Token): Unit {
        if (values.addIfAbsent(identifier.value,
            Reference(NodeIdManager.nextId(), identifier, None)).isSome())
        {
            println("Cannot redefine a variable with the same name in the " +
                "same scope")
            throw ParseError()
        }
    }

    public prop enclosing: ?Environment {
        get() { enclosing_ }
    }

    public prop isGlobal: Bool {
        get() { return enclosing.isNone() }
    }
}