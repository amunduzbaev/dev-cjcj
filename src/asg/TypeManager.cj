package cjcj.asg

import cjcj.visitor.Type
import cjcj.visitor.FuncReference
import cjcj.scanner.Token
import cjcj.visitor.Reference

import stdx.effect.*
import std.collection.*

public class TypeEffect <: Command<Type> {
    public TypeEffect(private let ref_: Reference) {}

    public prop ref: Reference {
        get() { ref_ }
    }
}

public class TypeManager {

    // Returns the concatenation of the string representation of the hash of the funcName and of the
    // name of the types.
    public static func funcHashConcat(funcName: String, paramsTypeName: Array<String>): String {
        funcName + paramsTypeName.iterator()
            .map({ t => t.hashCode().toString() })
            .fold(StringBuilder(), { acc, v => acc.append(v); acc }).toString()
    }

    public static func funcHashConcat(funcName: String, params: Array<Type>): String {
        funcHashConcat(funcName,
            Utils.fold(params.iterator().map({ t => t.name }), ArrayList()).toArray())
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

    public prop totalFuncDefGlobal: Map<String, ArrayStack<FuncReference>> {
        get() {
            let tmpTypeManager: TypeManager = this
            let res: Map<String, ArrayStack<FuncReference>> = HashMap()
            while (let Some(enclosing) <- tmpTypeManager.enclosing) {
                let mp = tmpTypeManager.totalFuncDef
                mp.iterator().forEach({ entry =>
                    let (funcName, overloads) = entry
                    res.addIfAbsent(funcName, ArrayStack())
                    overloads.iterator().forEach({ ref =>
                        res[funcName].add(ref)
                    })
                })
            }
            res
        }
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
            Utils.fold(parents.iterator().map({ s => getType(s)}), ArrayList()), isOpen))
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

    /*
    * Returns true if a function with the given name exists.
    */
    public func funcExists(funcName: String): Bool {
        totalFuncDef.get(funcName).isSome()
    }

    /*
    * Returns true if a function with the given name exists here or in some parent.
    */
    public func funcExistsGlobal(funcName: String): Bool {
        var tmpTypeManager: TypeManager = this
        while (let Some(enclosing) <- tmpTypeManager.enclosing) {
            if (tmpTypeManager.funcExists(funcName)) {
                return true
            }
            tmpTypeManager = enclosing
        }
        tmpTypeManager.funcExists(funcName)
    }

    public func exactFuncExists(funcHashConcat: String): Bool {
        immediateFuncDef.get(funcHashConcat).isSome()
    }

    public func exactFuncExistsGlobal(funcHashConcat: String): Bool {
        var tmpTypeManager: TypeManager = this
        while (let Some(enclosing) <- tmpTypeManager.enclosing) {
            if (tmpTypeManager.exactFuncExists(funcHashConcat)) {
                return true
            }
            tmpTypeManager = enclosing
        }
        tmpTypeManager.exactFuncExists(funcHashConcat)
    }

    /*
    * For a function call with name, arguments and expected return type, groups all the overloads
    * that respect the argument constraints by return type. Every function is added in all groups
    * of the ancestors of its return type. Then the best function between all groups is chosen.
    */
    private func functionTypeGroup(
        funcName: String, args: Array<Set<Type>>, expectedReturnType: ?Type
    ): Map<Type, ?FuncReference> {
        let candidates: ArrayStack<FuncReference> =
            allFunctionsLocal(funcName, args, expectedReturnType)

        let returnTypeGrouping: Map<Type, Set<FuncReference>> = HashMap()

        candidates.iterator().forEach({ f: FuncReference =>
            let returnType: Type = if (f.effectiveType.isNone()) {
                // If I don't know the type I ask for it.
                perform TypeEffect(f)
            } else {
                f.effectiveType.getOrThrow()
            }
            returnType.ancestors.iterator().forEach({ a =>
                if(let Some(prev) <- returnTypeGrouping.get(a)) {
                    prev.add(f)
                    return
                }
                returnTypeGrouping.add(a, HashSet(ArrayList([f])))
            })
        })

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
    * Returns the grouping by return type of the functions that respect the name and args given.
    * In the grouping some links may be None because there's no best function, it means that the
    * type is impossible to get.
    */
    public func applyFunction(funcName: String, args: Array<Set<Type>>,
        expectedReturnType: ?Type): Map<Type, ?FuncReference>
    {
        var tmpTypeManager: TypeManager = this
        var res: Map<Type, ?FuncReference> = HashMap()
        while(let Some(enclosing) <- tmpTypeManager.enclosing && res.isEmpty()) {
            res = tmpTypeManager.functionTypeGroup(funcName, args, expectedReturnType)
            tmpTypeManager = enclosing
        }
        if (res.isEmpty()) {
            return tmpTypeManager.functionTypeGroup(funcName, args, expectedReturnType)
        }
        res
    }

    /*
    * Returns all the functions visible by the current environment that are compatible with the
    * argument types and expected return type.
    * If there are multiple functions with the exact same parameters the closest one will be chosen.
    */
    public func allFunctionsGlobal(funcName: String, args: Array<Set<Type>>): Map<Type, ?FuncReference> {
        let map: Map<Type, ?FuncReference> = HashMap()

        let signs: Set<String> = HashSet()
        var tmpTypeManager = this
        while (let Some(enclosing) <- tmpTypeManager.enclosing) {
            tmpTypeManager.accumulateGroup(funcName, args, map, signs)
            tmpTypeManager = enclosing
        }
        tmpTypeManager.accumulateGroup(funcName, args, map, signs)
        map
    }

    private func accumulateGroup(funcName: String, args: Array<Set<Type>>, 
        map: Map<Type, ?FuncReference>, signatures: Set<String>
    ): Unit {
        functionTypeGroup(funcName, args, None)
            .iterator().forEach({ entry =>
                // We want to keep only the first type and unique signatures.
                if (let Some(f) <- entry[1]) {
                    if (signatures.add(
                        funcHashConcat(funcName, Utils.refToType(f.paramRef.getOrThrow()))
                    )) {
                        map.addIfAbsent(entry[0], entry[1])
                    }
                    return
                }
                map.addIfAbsent(entry[0], entry[1])
            })
    }

    private func allFunctionsLocal(funcName: String, args: Array<Set<Type>>,
        expectedReturnType: ?Type
    ): ArrayStack<FuncReference> {
        if (let Some(paramsList) <- totalFuncDef.get(funcName)) {
            let validParamsList: ArrayStack<FuncReference> = Utils.foldToStack(paramsList.iterator()
                .filter({ f => f.paramRef.isSome() })
                .filter({ f => f.paramRef.getOrThrow().size == args.size }), ArrayStack())
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
        let commonSuperTypes: Array<Type> = Utils.fold(a.ancestorSet.iterator()
            .filter({ t => ancB.contains(t) }), ArrayList()).toArray()
        let validCandidates = Utils.fold(commonSuperTypes.iterator()
            .filter({ t => t.ancestorSet.contains(all: commonSuperTypes) }), ArrayList())
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

    public prop isGlobal: Bool {
        get() { enclosing.isNone() }
    }

    public func deleteHistory(): Unit {
        enclosing_ = None
    }
}
