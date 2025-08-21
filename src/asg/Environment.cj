package cjcj.asg

import cjcj.scanner.Token
import cjcj.parser.ParseError

import std.collection.Map
import std.collection.HashMap

class Environment {
    let enclosing: ?Environment
    private let values: Map<String, ?Reference> = HashMap()

    init(enclosing: ?Environment) {
        this.enclosing = enclosing
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
        // thrown. (Recursion is clean but slow needs optimization)
        if (enclosing.isSome()) {
            return enclosing.getOrThrow().get(identifier)
        }

        // Temporary usage of parseError that will change to a more specific
        // error in the future.
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
        if (values.addIfAbsent(identifier.value, None).isSome()) {
            println("Cannot redefine a variable with the same name in the " +
                "same scope")
            throw ParseError()
        }
    }

    public prop isGlobal: Bool {
        get() { return enclosing.isNone() }
    }

    // func getAt(distance: Int64, identifier: Token): Reference {
    //     ancestor(distance).get(identifier)
    // }

    // func assignAt(distance: Int64, identifier: Token, value: Reference): Unit {
    //     ancestor(distance).values.add(identifier.value, value)
    // }

    // func ancestor(distance: Int64): Environment {
    //     var environment: Environment = this
    //     for (i in 0..distance) {
    //         environment = environment.enclosing.getOrThrow({ =>
    //             UnsupportedException("Wrong ancestor distance given.")})
    //     }
    //     environment
    // }
}