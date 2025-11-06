package cjcj.asg

import cjcj.visitor.*
import std.collection.ArrayList
import std.collection.List
import std.collection.Stack

public abstract class Utils {
    // Returns the concatenation of the string representation of the hash of the funcName and of the
    // name parameter types
    // [Note] Does not include the declared return type even if exists. 
    public static func funcHashConcat(funcDecl: FuncDecl): String {
        funcDecl.identifier.value + "|" +
            funcDecl.params.iterator().map({t => t.paramType.typeName.value + "|"}).fold(
            StringBuilder(),
            {
                acc, v =>
                    acc.append(v);
                    acc
            }
        ).toString()
    }

    public static func funcHashConcat(funcRef: FuncReference): String {
        funcRef.identifier.value + "|" +
            Utils.refToType(funcRef.paramRef.getOrThrow()).iterator().map({t => t.name + "|"}).fold(
            StringBuilder(),
            {
                acc, v =>
                    acc.append(v);
                    acc
            }
        ).toString()
    }

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
        paramRef.iterator().enumerate().forEach({
            p => p[1].effectiveType = typeManager.getType(funcParams[p[0]].paramType.typeName.value)
        })
    }

    /*
     * Returns a list of effective types of the references.
     * @param refs the list of references
     */
    public static func refToType<T>(refs: ArrayList<T>): Array<Type> where T <: Reference {
        refs.iterator().map({p => p.effectiveType.getOrThrow()}).fold<ArrayList<Type>>(
            ArrayList(),
            {
                acc, v =>
                    acc.add(v);
                    acc
            }
        ).toArray()
    }

    /*
     * Folds an iterator into a List.
     */
    public static func fold<T, R>(it: Iterator<T>, base: R): R where R <: List<T> {
        it.fold<R>(
            base,
            {
                acc, v =>
                    acc.add(v);
                    acc
            }
        )
    }

    public static func foldToStack<T, R>(it: Iterator<T>, base: R): R where R <: Stack<T> {
        it.fold<R>(
            base,
            {
                acc, v =>
                    acc.add(v);
                    acc
            }
        )
    }
}
