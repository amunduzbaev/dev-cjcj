package cjcj.asg.typeChecker

import cjcj.visitor.Type
import cjcj.visitor.FuncReference
import cjcj.scanner.Token

import std.collection.*
import std.sort.*

/*
* Defines an Environment in which every identifier has some data attached to it. Each environment
* knows who was before him and is able to provide identifiers' references by going up the cactus.
* (From every environment there's only one way to the root)
*/
private class Environment {
    private let enclosing_: ?Environment

    /*
    * Contains all the functions defined. For each function we keep the concatenation of the hash
    * of the type names and the relative return type. This works for exact match.
    * We also keep the list of all the overloads to find a good target if there's no perfect match.
    */
    private let funcReferences: Map<String, (Map<String,  FuncReference>, ArrayStack< FuncReference>)>

    public init(enclosing: ?Environment) {
        enclosing_ = enclosing
        funcReferences = HashMap()
    }

    public init() {
        this(None)
    }

    // Looks for the identifier in this and all parent environments.
    public func getGlobal(identifier: String): (Map<String,  FuncReference>, ArrayStack< FuncReference>) {
        getLocal(identifier).getOrDefault({ =>
            enclosing.getOrThrow({ =>
                Exception("Undefined identifier '${identifier.toString()}'.")
            }).getGlobal(identifier)
        })
    }

    // Looks for the identifier in this environment.
    public func getLocal(identifier: String): ?(Map<String,  FuncReference>, ArrayStack< FuncReference>) {
        funcReferences.get(identifier)
    }

    public func declareFunc(reference: FuncReference, stringify: (Array<Type>) -> String): Unit {
        let identifier: String = reference.identifier.value
        let params: Array<Type> = reference.paramRef.getOrThrow().iterator()
            .map({ p => p.effectiveType.getOrThrow() })
            .fold<ArrayList<Type>>(ArrayList(), { res, v => res.add(v); res }).toArray()
        if (let Some((fun, funList)) <- getLocal(identifier)) {
            if (let Some(prec) <- fun.addIfAbsent(stringify(params), reference)) {
                let paramString: String = params.iterator().map({ t => t.name })
                    .reduce({ a, b => a + "," + b }).getOrDefault({ => "" })
                throw Exception("Multiple declaration of func ${identifier} (${paramString})")
            }
            funList.add(reference)
        } else {
            funcReferences.add(identifier, (HashMap(), ArrayStack()))
            declareFunc(reference, stringify)
        }
    }

    public prop enclosing: ?Environment {
        get() { enclosing_ }
    }

    public prop isGlobal: Bool {
        get() { return enclosing.isNone() }
    }
}

public class TypeManager {

    // Returns the concatenation of the string representation of the hash of the name of the types.
    private static func paramHashConcat(params: Array<Type>): String {
        params.iterator().map({ t => t.name.hashCode().toString() })
        // TODO: Optimize string concatenation using string builder.
            .reduce({ a, b => a + b }).getOrDefault({ => "" })
    }

    private let nameToType: Map<String, Type> = HashMap()
    private var currentEnvironment: Environment = Environment()

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
    * Extension for method applyFunction
    * For a function call with name : funcName and arguments : params
    * Find the function which is the closest to the types of arguments in the call and returns its 
    * return type. 
    * In other words, find the function where each parameter type is the subtype of the types of the
    * parameters at the same index in other functions and return its return type. If there is no 
    * such function, throw an error. 
    */
    private func findClosestSuperType(funcName: String, params: Array<Type>,
        expectedReturnType: ?Type): FuncReference
    {
        findClosestSuperType(funcName, params, expectedReturnType, currentEnvironment)
    }

    private func findClosestSuperType(funcName: String, params: Array<Type>,
        expectedReturnType: ?Type, environment: Environment): FuncReference
    {
        if (let Some((_, paramsList)) <- environment.getLocal(funcName)) {
            let candidates: ArrayStack<FuncReference> = params.iterator().enumerate()
                .fold(paramsList, { 
                    consider: ArrayStack<FuncReference>, entry: (Int64, Type) =>
                        let (id, curType) = entry 

                        consider.iterator().fold<ArrayStack<FuncReference>>(ArrayStack(), 
                        { acc: ArrayStack<FuncReference>, candidate: FuncReference =>
                            let candidateParams: ArrayList<Type> = candidate.paramRef.getOrThrow()
                                .iterator().map({ c => c.effectiveType.getOrThrow() })
                                .fold(ArrayList(), { acc, t => acc.add(t); acc })
                            let candidateReturn: Type = candidate.effectiveType.getOrThrow()
                            if (candidateParams.size == params.size && 
                                (curType.ancestorSet.contains(candidateParams[id]) ||
                                    curType == candidateParams[id])
                            ){
                                // TODO: Maybe this if can be rewritten better.
                                if (let Some(expectedRet) <- expectedReturnType) {
                                    if (expectedRet.isParent(candidateReturn)) {
                                        acc.add(candidate)
                                    }
                                } else {
                                    acc.add(candidate)
                                }
                            }
                            acc
                        })
                })

            if (candidates.isEmpty()) {
                if (environment.enclosing.isSome()) {
                    return findClosestSuperType(funcName, params, expectedReturnType,
                        environment.enclosing.getOrThrow())
                } else {
                    let paramString: String = params.iterator().map({ t => t.name })
                        .reduce({ a, b => a + "," + b }).getOrDefault({ => "" })
                    throw Exception("Function ${funcName} is not defined for (${paramString})")
                }
            }

            let closests: ArrayList<Array<Type>> = candidates.iterator()
                .map({ c => c.paramRef.getOrThrow().iterator()
                    .map({ v => v.effectiveType.getOrThrow() })
                    .fold<ArrayList<Type>>(ArrayList(), { res, v => res.add(v); res }).toArray()
                })
                .fold<ArrayList<Array<Type>>>(ArrayList(), { 
                    closestOptions: ArrayList<Array<Type>>, candidate: Array<Type> =>

                        let canReach = candidate.iterator().enumerate().all({ entry => 
                            let (column, curType) = entry
                            let curAncestors = curType.ancestorSet
                            candidates.iterator().map({ c => c.paramRef.getOrThrow().iterator()
                                .map({ v => v.effectiveType.getOrThrow() })
                                .fold<ArrayList<Type>>(ArrayList(), { res, v => res.add(v); res }).toArray()
                            }).all({
                                otherCandidate: Array<Type> =>
                                    curAncestors.contains(otherCandidate[column])
                            })
                        })
                        if(canReach) { closestOptions.add(candidate) }
                        closestOptions
                })
            if (closests.size != 1) {
                let paramString: String = params.iterator().map({ t => t.name })
                    .reduce({ a, b => a + "," + b }).getOrDefault({ => "" })
                let candidates: String = closests.iterator().map({ p => p.iterator()
                    .map({ t => t.name })
                    .reduce({ a, b => a + "," + b }).getOrDefault({ => "" }) })
                    .reduce({ a, b => a + "\n" + b }).getOrDefault({ => "" })
                throw Exception("Function ${funcName} has ambiguous call options for " +
                    "${paramString}, candidates:\n ${candidates}")
            }

            // I could also call it with expectedReturnType None because I know exactly the function
            return applyFunction(funcName, closests[0], expectedReturnType)
        }
        findClosestSuperType(funcName, params, expectedReturnType,
            environment.enclosing.getOrThrow())
    }

    /*
    * Returns the reference of the function called with the given parameters.
    */
    public func applyFunction(funcName: String, params: Array<Type>,
        expectedReturnType: ?Type): FuncReference
    {
        // TODO: If there are candidates with parameters but not with expected return take the first
        // and print something like (expected "this" found "that" where that is the first)
        let (fun, _) = currentEnvironment.getGlobal(funcName)
        match (fun.get(paramHashConcat(params))) {
            case Some(returnType) => returnType
            case _ => findClosestSuperType(funcName, params, expectedReturnType)
        }
    }

    public func addFunction(reference: FuncReference): Unit {
        currentEnvironment.declareFunc(reference, paramHashConcat)
    }

    /*
    * Returns the common supertype that is closer to both types if it exists and it's unique. The
    * target type is the one of the common supertypes that is a subtype of all the others.
    */
    public func smallestCommonSupertype(a: Type, b: Type): Type {
        if (a == b) { return a }
        let ancB: Set<Type> = b.ancestorSet
        let commonSuperTypes: Array<Type> = a.ancestorSet.iterator()
            .filter({ t => ancB.contains(t) })
            .fold<ArrayList<Type>>(ArrayList(), { res, v => res.add(v); res }).toArray()
        let validCandidates = commonSuperTypes.iterator()
            .filter({ t => t.ancestorSet.contains(all: commonSuperTypes) })
            .fold<ArrayList<Type>>(ArrayList(), { res, v => res.add(v); res })
        if (validCandidates.size != 1) {
            throw Exception("Cannot find smallest common supertype")
        }
        return validCandidates[0]
    }

    public func beginScope(): Unit {
        currentEnvironment = Environment(currentEnvironment)
        // lastKilledEnvironment = None
    }

    public func endScope(): Unit {
        // lastKilledEnvironment = currentEnvironment
        currentEnvironment = currentEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
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
