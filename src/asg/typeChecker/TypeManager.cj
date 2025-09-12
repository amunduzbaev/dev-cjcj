package cjcj.asg.typeChecker

import cjcj.visitor.Type
import cjcj.visitor.FuncReference
import cjcj.visitor.VariableReference
import cjcj.visitor.Environment
import cjcj.scanner.Token

import std.collection.*
import std.sort.*

public class TypeManager {

    // Returns the concatenation of the string representation of the hash of the funcName and of the
    // name of the types.
    public static func funcHashConcat(funcName: String, params: Array<Type>): String {
        funcName + params.iterator()
            .map({ t => t.name.hashCode().toString() })
            .fold(StringBuilder(), { acc, v => acc.append(v); acc }).toString()
    }

    private let nameToType: Map<String, Type> = HashMap()
    private var immediateFuncEnvironment: Environment<String, FuncReference> = Environment()
    private var totalFuncEnvironment: Environment<String, ArrayStack<FuncReference>> = Environment()

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
    private func findClosestSuperType(
        funcName: String, params: Array<Type>, expectedReturnType: ?Type,
        environment: Environment<String, ArrayStack<FuncReference>>
    ): ?FuncReference {
        if (let Some(paramsList) <- environment.getLocal(funcName)) {
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
                return None
            }

            let closests: ArrayList<Array<Type>> = candidates.iterator()
                .map({ c => TypeCheckerHelper.refToType(c.paramRef.getOrThrow()) })
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
        None
    }

    /*
    * Returns the reference of the function called with the given parameters.
    */
    public func applyFunction(funcName: String, params: Array<Type>,
        expectedReturnType: ?Type): FuncReference
    {
        var tmpImmediateFuncEnvironment = immediateFuncEnvironment
        var tmpTotalFuncEnvironment = totalFuncEnvironment
        var res: ?FuncReference = None
        // TODO: If there are candidates with parameters but not with expected return take the first
        // and print something like (expected "this" found "that" where that is the first)
        while(let Some(enclosingImmediate) <- tmpImmediateFuncEnvironment.enclosing &&
            let Some(enclosingTotal) <- tmpTotalFuncEnvironment.enclosing &&
            res.isNone()
        ) {
            res = match (tmpImmediateFuncEnvironment.getLocal(funcHashConcat(funcName, params))) {
                case Some(funcRef) => funcRef
                case _ => findClosestSuperType(funcName, params, expectedReturnType, tmpTotalFuncEnvironment)
            }
            tmpImmediateFuncEnvironment = enclosingImmediate
            tmpTotalFuncEnvironment = enclosingTotal
        }
        if (res.isNone()) {
            res = match (tmpImmediateFuncEnvironment.getLocal(funcHashConcat(funcName, params))) {
                case Some(returnType) => returnType
                case _ => findClosestSuperType(funcName, params, expectedReturnType, tmpTotalFuncEnvironment)
            }
        }
        res.getOrThrow({ => Exception("Function ${funcName} doesn't exist and couldn't find a " +
            "right candidate based on params and returntype") })
    }

    public func addFunction(reference: FuncReference): Unit {
        let funcName: String = reference.identifier.value
        let params: Array<Type> = TypeCheckerHelper.refToType(reference.paramRef.getOrThrow())

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
        immediateFuncEnvironment = Environment(immediateFuncEnvironment)
        totalFuncEnvironment = Environment(totalFuncEnvironment)
    }

    public func endScope(): Unit {
        immediateFuncEnvironment = immediateFuncEnvironment.enclosing.getOrThrow({ =>
            UnsupportedException("Trying to close the global scope") })
        totalFuncEnvironment = totalFuncEnvironment.enclosing.getOrThrow({ =>
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
