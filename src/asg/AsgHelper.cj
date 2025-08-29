package cjcj.asg

import cjcj.visitor.*
import std.env.getStdOut
import std.collection.HashSet
import std.collection.HashMap
import std.collection.ArrayList

func sswap<T>(a: T, b: T): (T, T) where T <: Less<T>{
    if(b < a) {
        return (b, a)
    }
    (a, b)
}

func swap<T>(a: T, b: T): (T, T) {
    return (b, a)
}

interface Less<T> {
    operator func < (other: T) : Bool 
}

extend<T> HashSet<T> <: Less<HashSet<T>> where T <: Hashable & Equatable<T>{
    public operator func < (other:HashSet<T>) : Bool {
        this.size < other.size
    }
}

extend<T> ArrayList<T> <: Less<ArrayList<T>> {
    public operator func < (other:ArrayList<T>) : Bool {
        this.size < other.size
    }
}

extend<K, V> HashMap<K, V> <: Less<HashMap<K, V>> where K <: Hashable & Equatable<K> {
    public operator func < (other: HashMap<K, V>) : Bool {
        this.size < other.size
    }
}

public class InitsRefs {
    private var inits_: HashMap<Reference, Node>
    private var refs_: HashMap<Reference, ArrayList<Node>>
    private var assrefs_: HashMap<Reference, ArrayList<Node>>
    private var mutated_: HashMap<Reference, ArrayList<Node>>

    // inits_: HashSet of references of initialised variables in this environment
    // refs_: HashMap of variables who are referenced and have to be initialized but not initialized
    // yet, with mapping to the exact expression where the variable is referenced
    // assrefs_: HashMap of variables who are referenced in an assignment(left) but not initialized 
    // yet, with mapping to the exact expression where the variable is referenced
    // we don't know yet whether we have to initialize assrefs, we add them into references that
    // have to be initialized when we leave a function (or main)
    // mutated 

    public init() {
        inits_ = HashMap<Reference, Node>()
        refs_ = HashMap<Reference, ArrayList<Node>>()
        assrefs_ = HashMap<Reference, ArrayList<Node>>()
        mutated_ = HashMap<Reference, ArrayList<Node>>()
    }
    
    public init(inits: HashMap<Reference, Node>, refs: HashMap<Reference, ArrayList<Node>>, 
                assrefs: HashMap<Reference, ArrayList<Node>>, 
                mutated: HashMap<Reference, ArrayList<Node>> ) {
        inits_ = inits
        refs_ = refs
        assrefs_ = assrefs
        mutated_ = mutated
    }

    /* Do not modify */
    // private func merge<T, V>(setA_:HashMap<T, V>, setB_: HashSet<T>) : 
    //         (HashSet<T>, HashSet<T>) where T <: Hashable & Equatable<T> {
    //     var (setA, setB) = sswap(setA_, setB_)
    //     setB.add(all: setA.toArray())
    //     setA.clear()

    //     (setB, setA)
    // }

    private func merge<T>(listA_: ArrayList<T>, listB_: ArrayList<T>) : 
            (ArrayList<T>, ArrayList<T>) {
        var (listA, listB) = swap(listA_, listB_)
        listB.add(all: listA)
        listA.clear()

        (listB, listA)
    }

    // what is the time complexity of adding big element into collections like HashSet or HashMap?
    private func merge<T, V>(mapA_: HashMap<T, ArrayList<V>>, 
                            mapB_: HashMap<T, ArrayList<V>>) : 
            (HashMap<T, ArrayList<V>>, HashMap<T, ArrayList<V>>) where T <:Hashable & Equatable<T> {
        var (mapA, mapB) = sswap(mapA_, mapB_)
        for(entry in mapA.toArray()){
            var (ref, nodeList) = entry

            nodeList = match (mapB.get(ref)) {
                case Some(otherNodeList) => merge(nodeList, otherNodeList)[0]
                case _ => nodeList
            }

            mapB.add(ref, nodeList)
        }
        mapA.clear()

        (mapB, mapA)
    }

    private func merge<T, V>(mapA_: HashMap<T, V>, mapB_: HashMap<T, V>) : 
            (HashMap<T, V>, HashMap<T, V>, HashMap<T, V>) 
            where T <:Hashable & Equatable<T> {
        var (mapA, mapB) = sswap(mapA_, mapB_)
        var remaining: HashMap<T, V> = HashMap()
        for(entry in mapA.toArray()){
            var (ref, node) = entry

            match (mapB.get(ref)) {
                case Some(otherNode) => remaining.add(ref, node)
                case _ => mapB.add(ref, node)
            }
        }
        mapA.clear()

        (mapB, mapA, remaining)
    }

    private func cancelInitlaizedReferences(someInits: HashMap<Reference, Node>, 
                             someRefs: HashMap<Reference, ArrayList<Node>>) :
                            (HashMap<Reference, Node>, HashMap<Reference, ArrayList<Node>>) {
        if(someInits.size > someRefs.size) {
            let arr = someRefs.toArray()
            for(entry in arr) {
                let (ref, _) = entry
                if(someInits.contains(ref)) {
                    someRefs.remove(ref)
                }
            }
        } else {
            let arr = someInits.toArray()
            for(entry in arr){
                let (ref, _) = entry
                if(someRefs.contains(ref)) {
                    someRefs.remove(ref)
                }
            }
        }

        (someInits, someRefs)
    }

    public func merge(other: InitsRefs) {
        var newMutated: HashMap<Reference, Node>
        
        (inits, other.inits, newMutated) = merge(inits, other.inits)
        let foldedMutated = newMutated.iterator().fold(HashMap<Reference, ArrayList<Node>>(), {
            map: HashMap<Reference, ArrayList<Node>>, entry: (Reference, Node) => 
                map.add(entry[0], ArrayList<Node>([entry[1]]))
                map
        })
        (mutated, _) = merge(mutated, foldedMutated)

        (refs,  other.refs) =  merge(refs, other.refs)
        (assrefs, other.assrefs) = merge(assrefs, other.assrefs)
        (mutated, other.mutated) = merge(mutated, other.mutated)
    }

    // Merging with other InitsRefs
    public func mergeL(other: InitsRefs) {
        (inits, other.refs) = cancelInitlaizedReferences(inits, other.refs)
        (inits, other.assrefs) = cancelInitlaizedReferences(inits, other.assrefs)
        merge(other)
    }
    public func mergeR(other: InitsRefs) {
        (other.inits, refs) = cancelInitlaizedReferences(other.inits, refs)
        (other.inits, assrefs) = cancelInitlaizedReferences(other.inits, assrefs)
        merge(other)
    }
    public func bramchMerge(other: InitsRefs) {
        (_, other.inits, inits) = merge(inits, other.inits)
        merge(other)
    }

    // Editing and Asking information about reference or initialization of variables
    public func initialized(ref: Reference, node: Node) {
        inits.add(ref, node)
    }

    public func referenced(ref: Reference, node: Node) {
        let nodeList = match (refs.get(ref)) {
            case Some(nodeList) => nodeList
            case _ => ArrayList<Node>()
        }
        nodeList.add(node)

        refs.add(ref, nodeList)
    }

    private func addAssignment<T, V>(map: HashMap<T, ArrayList<V>>, a: T, b: V) : Unit
        where T <: Hashable & Equatable<T>{
        var vList = match (map.get(a)) {
            case Some(vList) => vList
            case _ => ArrayList<V>()
        }
        vList.add(b)

        map.add(a, vList)
    }

    public func assigned(ref: Reference, node: Node) {
        addAssignment(assrefs, ref, node)
        // addAssignment(mutated, ref, node)
    }

    public func clearInits() {
        inits.clear()
    }

    public func isInitialized(ref: Reference) : ArrayList<(Reference, Node)>{
        match (refs.get(ref)) {
            case Some(exprList: ArrayList<Node>) =>
                refs.remove(ref)
                exprList.iterator().fold(ArrayList<(Reference, Node)>(), 
                { arr: ArrayList<(Reference, Node)>, d: Node => 
                    arr.add((ref, d))
                    arr 
                })
            case _ => ArrayList<(Reference, Node)>()
        }
    }

    public func isMutated(ref: Reference) : ArrayList<(Reference, Node)> {
        match (mutated.get(ref)) {
            case Some(exprList: ArrayList<Node>) =>
                mutated.remove(ref)
                exprList.iterator().fold(ArrayList<(Reference, Node)>(), 
                { arr: ArrayList<(Reference, Node)>, d: Node => 
                    arr.add((ref, d))
                    arr 
                })
            case _ => ArrayList<(Reference, Node)>()
        }
    }

    public func assignsMustBeInitialized() {
        (refs, assrefs) = merge(refs, assrefs)
    }

    private mut prop inits: HashMap<Reference, Node> {
        get() { inits_ }
        set(v) { inits_ = v }
    }

    private mut prop refs: HashMap<Reference, ArrayList<Node>> {
        get() { refs_ }
        set(v) { refs_ = v }
    }

    private mut prop assrefs: HashMap<Reference, ArrayList<Node>> {
        get() { assrefs_ }
        set(v) { assrefs_ = v }
    }

    private mut prop mutated: HashMap<Reference, ArrayList<Node>> {
        get() { mutated_ }
        set(v) { mutated_ = v }
    }
}

