package cjcj.asg

import cjcj.visitor.Type
import cjcj.visitor.FuncReference
import cjcj.scanner.Token
import cjcj.visitor.Visitor

import stdx.effect.*
import std.collection.*

public class VisitorEffect<T> <: Command<Visitor<T>> {}

public class TypeManager {

    // Returns the concatenation of the string representation of the hash of the funcName and of the
    // name of the types.
    public static func funcHashConcat(funcName: String, params: Array<Type>): String {
        funcName + "|" + params.iterator()
            .map({ t => t.name.hashCode().toString() + "|" })
            .fold(StringBuilder(), { acc, v => acc.append(v); acc }).toString()
    }

    private var enclosing_: ?TypeManager = None
    private var nameToType_: Map<String, Type> = HashMap()
    private var immediateFuncDef_: Map<String, FuncReference> = HashMap()
    private var totalFuncDef_: Map<String, ArrayStack<FuncReference>> = HashMap()

    public prop nameToType: Map<String, Type> {
        get() { nameToType_ }
    }

    public prop immediateFuncDef: Map<String, FuncReference> {
        get() { immediateFuncDef_ }
    }

    public prop totalFuncDef: Map<String, ArrayStack<FuncReference>> {
        get() { totalFuncDef_ }
    }

    public prop enclosing: ?TypeManager {
        get() { enclosing_ }
    }

    public init() {
    }

    public init(typeManager: TypeManager) {
        enclosing_ = typeManager
        nameToType_ = typeManager.nameToType_
    }

    // Sets the typeManager member as a parent of this members.
    public func setEnclosing(parent: TypeManager): Unit {
        enclosing_ = parent
    }

    /*
    * Adds a type to the map if the type is not already defined.
    */
    public func addType(typeName: String, parents: ArrayList<String>, isOpen!: Bool = false): Unit {
        addType(Type(typeName,
            parents.iterator().map({ s => getType(s)}).fold(ArrayList<Type>(),
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
    public func getType(typeName: String): Type {
        nameToType.get(typeName).getOrThrow({ => Exception("Type ${typeName} does not exist")})
    }

    public func funcExists(funcName: String): Bool {
        return (totalFuncDef.get(funcName).isSome())
    }

    /*
    * Extension for method applyFunction
    * For a function call with name : funcName and arguments : args
    * Find the functions which are the closest to the types of arguments in the call and returns its
    * references. 
    * In other words, find the functions where each parameter type is the subtype of the types of
    * the parameters at the same index in other functions and return its reference.
    */
    public func findClosestSuperType(
        funcName: String, args: Array<Set<Type>>, expectedReturnType: ?Type
    ): Map<Type, ?FuncReference> {
        let candidates: ArrayStack<FuncReference> =
            allFunctionsLocal(funcName, args, expectedReturnType)

        let returnTypeGrouping: Map<Type, Set<FuncReference>> = HashMap()

        candidates.iterator().forEach({ f: FuncReference =>
            if (f.effectiveType.isNone()) {
                f.traverse(perform VisitorEffect<Unit>())
            }
            let returnType: Type = f.effectiveType.getOrThrow()
            // Every type is in the group of itself and its ancestors. 
            returnType.ancestors.iterator().forEach({ a =>
                if(let Some(prev) <- returnTypeGrouping.get(a)) {
                    prev.add(f)
                    return
                }
                returnTypeGrouping.add(a, HashSet(ArrayList([f])))
            })
        })

        // Take the best function for each return type.
        returnTypeGrouping.iterator().map({ funcs => (funcs[0], bestFunction(funcs[1])) })
            .fold<Map<Type, ?FuncReference>>(HashMap(), { acc, v => acc.add(v[0], v[1]); acc })
    }

    /*
    * Returns the best function of a list based on a ranking, the function chosen will be the one
    * whose parameters are subtype of all the other. Will return only if the result is unique.
    */
    public func bestFunction(funcs: Set<FuncReference>): ?FuncReference {
        let closests: ArrayList<FuncReference> = Utils.fold(funcs.iterator()
            .filter({ candidate: FuncReference =>
                    let paramTypes: Array<Type> = Utils.refToType(candidate.paramRef.getOrThrow())
                    let canReach = paramTypes.iterator().enumerate().all({ entry => 
                        let (column, curType) = entry
                        let curAncestors = curType.ancestorSet
                        funcs.iterator().map({ c => Utils.refToType(c.paramRef.getOrThrow()).toArray()
                            }).all({
                                otherCandidate: Array<Type> =>
                                    curAncestors.contains(otherCandidate[column])
                            })
                    })
                    canReach
            }), ArrayList())
        if (closests.size != 1) {
            return None
        }
        closests[0]
    }

    /*
    * Returns the reference of the possible function called with the given arguments.
    * Returns also the types that the functions can be. This happens because some types may be
    * impossible even though some functions that return a subtype may exist.
    */
    public func applyFunction(funcName: String, args: Array<Set<Type>>,
        expectedReturnType: ?Type): Map<Type, ?FuncReference>
    {
        var tmpTypeManager: TypeManager = this
        var res: Map<Type, ?FuncReference> = HashMap()
        while(let Some(enclosing) <- tmpTypeManager.enclosing && res.isEmpty()) {
            res = tmpTypeManager.findClosestSuperType(funcName, args, expectedReturnType)
            tmpTypeManager = enclosing
        }
        if (res.isEmpty()) {
            return tmpTypeManager.findClosestSuperType(funcName, args, expectedReturnType)
        }
        res
    }

    /*
    * Returns all the functions visible by the current environment that are compatible with the
    * argument types and expected return type.
    * If there are multiple functions with the exact same parameters the closest one will be chosen.
    */
    public func allFunctionsGlobal(
        funcName: String, args: Array<Set<Type>>, 
        collectSuperScopes: ?(() -> Map<Type, ?FuncReference>)
    ): Map<Type, ?FuncReference> {
        let map: Map<Type, ?FuncReference> = HashMap()

        let signs: Set<String> = HashSet()
        var tmpTypeManager = this

        let collect: (Map<Type, ?FuncReference>) -> Unit = { scopeMap =>
            let newSigns = ArrayList<String>()
            scopeMap.iterator().forEach({ entry => 
                // We want to keep only the first type and unique signatures.
                let (tp, funcRef) = entry
                if (let Some(f) <- funcRef) {
                    let funcHash = funcHashConcat(funcName, Utils.refToType(f.paramRef.getOrThrow()))
                    if (!signs.contains(funcHash)) {
                        newSigns.add(funcHash)
                        map.addIfAbsent(tp, funcRef)
                    }
                    return
                }
                map.addIfAbsent(tp, funcRef)
            })

            signs.add(all: newSigns)
        }

        while (let Some(enclosing) <- tmpTypeManager.enclosing) {
            collect(tmpTypeManager.findClosestSuperType(funcName, args, None))
            
            tmpTypeManager = enclosing
        }
        if (let Some(collectSuperScopes) <- collectSuperScopes) {
            collect(collectSuperScopes())
        }
        collect(tmpTypeManager.findClosestSuperType(funcName, args, None))
        map
    }

    private func allFunctionsLocal(funcName: String, args: Array<Set<Type>>,
        expectedReturnType: ?Type
    ): ArrayStack<FuncReference> {
        if (let Some(paramsList) <- totalFuncDef.get(funcName)) {
            let validParamsList: ArrayStack<FuncReference> = paramsList.iterator()
                .filter({ f => f.paramRef.isSome() })
                .filter({ f => f.paramRef.getOrThrow().size == args.size })
                .fold(ArrayStack(), { acc, v => acc.add(v); acc })
            
            // Weird things happen when you iterate through an empty list.
            if (args.size == 0) {
                return validParamsList
            }
            // Go through arguments.
            return args.iterator().enumerate()
                .fold(validParamsList, { 
                    consider: ArrayStack<FuncReference>, entry: (Int64, Set<Type>) =>
                        let (id, possArg) = entry 

                        // Go through functions and their parameters at index id, take only the ones
                        // that have the right number of parameters, a compatible return type and
                        // compatibles types with the arguments that are passed.
                        consider.iterator().fold<ArrayStack<FuncReference>>(ArrayStack(), 
                        { acc: ArrayStack<FuncReference>, candidate: FuncReference =>
                            let paramRef = candidate.paramRef.getOrThrow()
                            let paramType: Type = paramRef[id].effectiveType.getOrThrow()

                            if (let Some(expectedReturnType) <- expectedReturnType) {
                                let returnType: Type = candidate.effectiveType.getOrThrow()
                                if (!expectedReturnType.isParent(returnType)) {
                                    return acc
                                }
                            }

                            let canMatch: Bool = possArg.iterator().any({ arg =>
                                    paramType.isParent(arg)
                                })
                            if (canMatch) {
                                acc.add(candidate)
                            }
                            acc
                        })
                })
        }
        ArrayStack()
    }

    public func addFunction(reference: FuncReference): Unit {
        let funcName: String = reference.identifier.value
        let params: Array<Type> = Utils.refToType(reference.paramRef.getOrThrow())

        if (let Some(fun) <- immediateFuncDef.get(funcHashConcat(funcName, params)))
        {
            let paramString: String = params.iterator().map({ t => t.name })
                .reduce({ a, b => a + "," + b }).getOrDefault({ => "" })

            throw Exception("Multiple declaration of func ${funcName} (${paramString})")
        }

        immediateFuncDef.add(funcHashConcat(funcName, params), reference)
        if (let Some(funList) <- totalFuncDef.get(funcName)) {
            funList.add(reference)
            return
        }

        let stack: ArrayStack<FuncReference> = ArrayStack()
        stack.add(reference)
        totalFuncDef.add(funcName, stack)
    }

    /*
    * Returns the common supertype that is closer to both types if it exists and it's unique. The
    * target type is the one of the common supertypes that is a subtype of all the others.
    */
    public func smallestCommonSupertype(a: Type, b: Type): Type {
        if (a == b) { return a }
        if (a == Type.NOTHING) { return b }
        if (b == Type.NOTHING) { return a }
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

    /*
    * Returns the set of common supertypes that have no inner edges.
    */
    public func smallestCommonSupertypeSet(a: Type, b: Type): Set<Type> {
        let ancA: Set<Type> = a.ancestorSet
        let ancB: Set<Type> = b.ancestorSet
        let totAnc: ArrayList<Type> =
            Utils.fold(ancA.iterator().concat(ancB.iterator()), ArrayList())
        let union: Set<Type> = HashSet(totAnc)

        totAnc.iterator().forEach({ t => if (union.contains(t)) {
            union.remove(all: t.ancestorSet)
            union.add(t)
        } })
        union
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

    public prop isGlobal: Bool {
        get() { enclosing.isNone() }
    }

    public func deleteHistory(): Unit {
        enclosing_ = None
    }
}
