package cjcj.asg.typeChecker

import cjcj.visitor.Type
import cjcj.scanner.Token

import std.collection.*
import std.sort.*

public class TypeManager {

    // Returns the concatenation of the string representation of the hash of the name of the types.
    private static func funcHashConcat(params: Array<Type>): String {
        params.iterator().map({ t => t.name.hashCode().toString() })
        // TODO: Optimize string concatenation using string builder.
            .reduce({ a, b => a + b }).getOrDefault({ => "" })
    }

    private let nameToType: Map<String, Type> = HashMap()

    /*
    * Contains all the functions defined. For each function we keep the concatenation of the hash
    * of the type names and the relative return type. This works for exact match.
    */
    private let definedFunctions: Map<String, Map<String, Type>> = HashMap()

    /*
    * Adds a type to the map if the type is not already defined.
    */
    public func addType(typeName: String, parents: ArrayList<String>, isOpen!: Bool = false): Unit {
        addType(Type(typeName,
            parents.iterator().map({ s => get(s)}).fold(ArrayList<Type>(),
                { r: ArrayList<Type>, t: Type => r.add(t); r}
            ), isOpen))
    }

    /*
    * Adds a type to the map if the type is not already defined.
    */
    public func addType(typ: Type): Unit {
        if (let Some(prev) <- nameToType.get(typ.name)) {
            throw Exception("Type ${typ.name} already exists")
        }
        nameToType.add(typ.name, typ)
    }


    /*
    * Retrieves an existing type given the typeName.
    */
    public func get(typeName: String): Type {
        nameToType.get(typeName).getOrThrow({ => Exception("Type ${typeName} does not exist")})
    }

    /*
    * Returns the return type of the function called with the given parameters.
    */
    public func applyFunction(funcName: String, params: Array<Type>): Type {
        // TODO: right now we're checking only for exact match but we should not do that because a
        // function parameter may be a supertype and we still want to be able to call the function.
        definedFunctions.get(funcName).getOrThrow({ =>
            Exception("Function ${funcName} doesn't exist")
        }).get(funcHashConcat(params)).getOrThrow({ =>
            let paramString: String = params.iterator().map({ t => t.name })
                .reduce({ a, b => a + "," + b }).getOrDefault({ => "" })
            Exception("Function ${funcName} is not defined for (${paramString})")}
        )
    }

    public func addFunction(funcName: String, params: Array<Type>, returnType: Type): Unit {
        if (let Some(fun) <- definedFunctions.get(funcName)) {
            if (let Some(prev) <- fun.addIfAbsent(funcHashConcat(params), returnType)) {
                throw Exception("Function ${funcName} with params: (" + 
                    params.iterator().map({ t => t.name })
                    .reduce({ a, b => a + ',' + b }).getOrDefault({ => ""}) +
                        ") is already defined")
            }
        } else {
            let definitions: Map<String, Type> = HashMap()
            definitions.add(funcHashConcat(params), returnType)
            definedFunctions.add(funcName, definitions)
        }
    }

    /*
        Returns the common supertype that is closer to both types if it exists and it's unique.
    */
    public func smallestCommonSupertype(a: Type, b: Type): Type {
        if (a == b) { return a }
        // Returns the ordering first by root distance and then by name.
        let cmpRootName: (Type, Type) -> Ordering = { a, b =>
            let rootCmp = a.rootDist.compare(b.rootDist)
            if (rootCmp == Ordering.EQ) {
                return rootCmp
            }
            return a.name.compare(b.name)
        }
        let ancA: Array<Type> = a.ancestors
        sort(ancA, by: cmpRootName)
        let ancB: Array<Type> = b.ancestors
        sort(ancB, by: cmpRootName)
        var f: Int64 = 0
        var s: Int64 = 0
        while (f < ancA.size && s < ancB.size) {
            match (ancA[f].rootDist.compare(ancB[s].rootDist)) {
                case Ordering.LT => s++
                case Ordering.GT => f++
                case Ordering.EQ =>
                    let eqSub: (Array<Type>, Array<Type>) = equalSubarray(ancA[f..], ancB[s..],
                        { a, b => a.rootDist == b.rootDist}
                    )
                    let common: ArrayList<Type> = commonElements(eqSub[0], eqSub[1], { a, b =>
                        a.name.compare(b.name)
                    })
                    if (common.size == 1) {
                        return common[0]
                    } else if (common.size > 1) {
                        for (c in common) {
                            println(c.name)
                        }
                        throw Exception("Couldn't find the smallest common supertype, " +
                            "${common.size} possible candidates were found.")
                    }
                    f += eqSub[0].size; s += eqSub[1].size
            }
        }
        throw Exception("Cannot find smallest common supertype")
    }

    /*
    * Returns the contiguous subsequens starting from 0 where all the elements are equal.
    */
    private func equalSubarray<T>(a: Array<T>, b: Array<T>, equal: (T, T) -> Bool) {
        var f: Int64 = 0
        var s: Int64 = 0
        while (f < a.size && equal(a[f], a[0])) { f++ }
        while (s < b.size && equal(b[s], b[0])) { s++ }
        (a[0..f], b[0..s])
    }

    /*
    * Returns the common elements of 2 arrays sorted by the 'cmp' compare function.
    */
    private func commonElements<T>(a: Array<T>, b: Array<T>, cmp: (T, T) -> Ordering): ArrayList<T>{
        let res: ArrayList<T> = ArrayList()
        var f: Int64 = 0
        var s: Int64 = 0
        while (f < a.size && s < b.size) {
            match (cmp(a[f], b[s])) {
                case Ordering.LT => f++
                case Ordering.GT => s++
                case Ordering.EQ => res.add(a[f]); f++; s++
            }
        }
        res
    }
}
