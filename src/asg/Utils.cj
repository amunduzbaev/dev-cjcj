package cjcj.asg

import cjcj.visitor.*

import std.collection.ArrayList
import std.collection.List

abstract class Utils {
    /*
    * Assigns the effective types to the parameter references based on the func param declarations.
    * @param funcParams the list to take the types from
    * @param paramRef the list to update with the effective types
    * @param typeManager the manager to query types
    */
    public static func funcParamToParamRef(
        funcParams: ArrayList<FuncParam>,
        paramRef: ArrayList<VariableReference>,
        typeManager: TypeManager
    ): Unit {
        paramRef.iterator().enumerate().forEach({ p =>
            p[1].effectiveType = typeManager.getType(funcParams[p[0]].paramType.typeName.value) })
    }

    /*
    * Returns a list of effective types of the references.
    * @param refs the list of references
    */
    public static func refToType<T>(refs: ArrayList<T>): Array<Type> where T <: Reference {
        refs.iterator()
            .map({ p => p.effectiveType.getOrThrow() })
            .fold<ArrayList<Type>>(ArrayList(), { acc, v => acc.add(v); acc }).toArray()
    }

    /*
    * Folds an iterator into a List.
    */
    public static func fold<T, R>(it: Iterator<T>, base: R): R where R <: List<T> {
        it.fold<R>(base, { acc, v => acc.add(v); acc })
    }
}