package cjcj.asg

import cjcj.visitor.Type
import cjcj.visitor.FuncReference
import cjcj.visitor.Environment
import cjcj.scanner.Token

import std.collection.*

public class TypeManager {

    // Returns the concatenation of the string representation of the hash of the funcName and of the
    // name of the types.
    public static func funcHashConcat(funcName: String, params: Array<Type>): String {
        funcName + params.iterator()
            .map({ t => t.name.hashCode().toString() })
            .fold(StringBuilder(), { acc, v => acc.append(v); acc }).toString()
    }

    private var nameToType_: Map<String, Type> = HashMap()
    private var immediateFuncEnvironment_: Environment<String, FuncReference> = Environment()
    private var totalFuncEnvironment_: Environment<String, ArrayStack<FuncReference>> =Environment()

    public prop nameToType: Map<String, Type> {
        get() { nameToType_ }
    }

    public prop immediateFuncEnvironment: Environment<String, FuncReference> {
        get() { immediateFuncEnvironment_ }
    }

    public prop totalFuncEnvironment: Environment<String, ArrayStack<FuncReference>> {
        get() { totalFuncEnvironment_ }
    }

    public init() {

    }

    public init(typeManager: TypeManager) {
        immediateFuncEnvironment_ = typeManager.immediateFuncEnvironment
        totalFuncEnvironment_ = typeManager.totalFuncEnvironment
        nameToType_ = typeManager.nameToType_
    }

    // Sets the typeManager member as a parent of this members.
    public func setEnclosing(parent: TypeManager): Unit {
        // TODO: Think about adding some checks.
        immediateFuncEnvironment.enclosing = parent.immediateFuncEnvironment
        totalFuncEnvironment.enclosing = parent.totalFuncEnvironment
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
        totalFuncEnvironment.getGlobal(funcName).isSome()
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
    private func findClosestSuperType(
        funcName: String, args: Array<Array<Type>>, expectedReturnType: ?Type,
        environment: Environment<String, ArrayStack<FuncReference>>
    ): ArrayList<FuncReference> {
        if (let Some(paramsList) <- environment.getLocal(funcName)) {
            // Go through arguments.
            let candidates: ArrayStack<FuncReference> = args.iterator().enumerate()
                .fold(paramsList, { 
                    consider: ArrayStack<FuncReference>, entry: (Int64, Array<Type>) =>
                        let (id, possArg) = entry 

                        // Go through functions and their parameters at index id, take only the ones
                        // that have the right number of parameters, a compatible return type and
                        // compatibles types with the arguments that are passed.
                        consider.iterator().fold<ArrayStack<FuncReference>>(ArrayStack(), 
                        { acc: ArrayStack<FuncReference>, candidate: FuncReference =>
                            if (let Some(paramRef) <- candidate.paramRef) {
                                if (paramRef.size != args.size) {
                                    return acc
                                }
                                let returnType: Type = candidate.effectiveType.getOrThrow()
                                let paramType: Type = paramRef[id].effectiveType.getOrThrow()

                                if (let Some(expectedReturnType) <- expectedReturnType &&
                                    !expectedReturnType.isParent(returnType)
                                ) {
                                    return acc
                                }

                                let canMatch: Bool = possArg.iterator().any({ arg =>
                                        paramType.isParent(arg)
                                    })
                                if (canMatch) {
                                    acc.add(candidate)
                                }
                            }
                            acc
                        })
                })

            let returnTypeGrouping: Map<Type, ArrayList<FuncReference>> = HashMap()
            candidates.iterator().forEach({ f =>
                let returnType: Type = f.effectiveType.getOrThrow()
                // Every type is in the group of itself and its ancestors. 
                returnType.ancestors.iterator().forEach({ a =>
                    if(let Some(prev) <- returnTypeGrouping.get(a)) {
                        prev.add(f)
                        return
                    }
                    returnTypeGrouping.add(a, ArrayList([f]))
                })
            })

            // Take the lowest function for each return type.
            return Utils.fold<FuncReference, ArrayList<FuncReference>>(
                returnTypeGrouping.values().iterator().map({ funcs => lowerFunction(funcs) })
                    .filter({ f => f.isSome() }).map({ f => f.getOrThrow() }),
                ArrayList()
            )
        }
        ArrayList()
    }

    private func lowerFunction(funcs: ArrayList<FuncReference>): ?FuncReference {
        let closests: ArrayList<FuncReference> = Utils.fold(funcs.iterator()
            .filter({ candidate: FuncReference =>
                    let paramTypes: Array<Type> = Utils.refToType(candidate.paramRef.getOrThrow())
                    let canReach = paramTypes.iterator().enumerate().all({ entry => 
                        let (column, curType) = entry
                        let curAncestors = curType.ancestorSet
                        funcs.iterator().map({ c => Utils.fold(c.paramRef.getOrThrow().iterator()
                            .map({ v => v.effectiveType.getOrThrow() }), ArrayList()).toArray()
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
    * Returns the reference of the function called with the given parameters.
    */
    public func applyFunction(funcName: String, params: Array<Array<Type>>,
        expectedReturnType: ?Type): ArrayList<FuncReference>
    {
        // We can check for 100% match if we have only one option for each argument.
        var immediateParams: ?Array<Type> = None
        if (params.iterator().all({ poss => poss.size == 1 })) {
            immediateParams = Utils.fold(params.iterator().map({ v => v[0] }),ArrayList()).toArray()
        }

        var tmpImmediateFuncEnvironment = immediateFuncEnvironment
        var tmpTotalFuncEnvironment = totalFuncEnvironment
        var res: ArrayList<FuncReference> = ArrayList()
        // TODO: If there are candidates with parameters but not with expected return take the first
        // and print something like (expected "this" found "that" where that is the first)
        while(let Some(enclosingImmediate) <- tmpImmediateFuncEnvironment.enclosing &&
            let Some(enclosingTotal) <- tmpTotalFuncEnvironment.enclosing &&
            res.isEmpty()
        ) {
            if (let Some(immediateParams) <- immediateParams) {
                if (
                    let Some(immediate) <- checkImmediate(funcName, immediateParams,
                        tmpImmediateFuncEnvironment)
                ) {
                    res.add(immediate)
                    return res
                }
                tmpImmediateFuncEnvironment = enclosingImmediate
            }
            res = findClosestSuperType(funcName, params, expectedReturnType,
                tmpTotalFuncEnvironment)
            tmpTotalFuncEnvironment = enclosingTotal
        }
        if (res.isEmpty()) {
            if (let Some(immediateParams) <- immediateParams) {
                if (
                    let Some(immediate) <- checkImmediate(funcName, immediateParams,
                        tmpImmediateFuncEnvironment)
                ) {
                    res.add(immediate)
                    return res
                }
            }
            res = findClosestSuperType(funcName, params, expectedReturnType,
                tmpTotalFuncEnvironment)
        }
        res
    }

    private func checkImmediate(funcName: String, params: Array<Type>,
        environment: Environment<String, FuncReference>
    ): ?FuncReference {
        environment.getLocal(funcHashConcat(funcName, params))
    }

    public func addFunction(reference: FuncReference): Unit {
        let funcName: String = reference.identifier.value
        let params: Array<Type> = Utils.refToType(reference.paramRef.getOrThrow())

        if (let Some(fun) <- immediateFuncEnvironment.getLocal(funcHashConcat(funcName, params)))
        {
            let paramString: String = params.iterator().map({ t => t.name })
                .reduce({ a, b => a + "," + b }).getOrDefault({ => "" })

            throw Exception("Multiple declaration of func ${funcName} (${paramString})")
        }

        immediateFuncEnvironment.declare(funcHashConcat(funcName, params), reference)
        if (let Some(funList) <- totalFuncEnvironment.getLocal(funcName)) {
            funList.add(reference)
            return
        }

        let stack: ArrayStack<FuncReference> = ArrayStack()
        stack.add(reference)
        totalFuncEnvironment.declare(funcName, stack)
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
        immediateFuncEnvironment_ = Environment(immediateFuncEnvironment)
        totalFuncEnvironment_ = Environment(totalFuncEnvironment)
    }

    public func endScope(): Unit {
        immediateFuncEnvironment_ = immediateFuncEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
        totalFuncEnvironment_ = totalFuncEnvironment.enclosing.getOrThrow({ =>
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

    public prop isGlobal: Bool {
        get() { totalFuncEnvironment.isGlobal }
    }

    public func deleteHistory(): Unit {
        totalFuncEnvironment.enclosing = None
        immediateFuncEnvironment.enclosing = None
    }
}
