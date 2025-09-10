package cjcj.asg.InitCheck

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
    private var inits_: HashSet<Reference> 
    private var refs_: HashMap<Reference, ArrayList<Node>>
    private var assrefs_: HashMap<Reference, ArrayList<Node>>
    private var tmpInits_: HashMap<Reference, ArrayList<Node>>
    private var mutated_: HashMap<Reference, ArrayList<Node>>

    // DEF inits_: HashSet of references of initialised variables in this environment
    
    // Reference in expression Check
    // DEF refs_: HashMap of variables who are referenced and have to be initialized but not 
    // initialized yet, with mapping to the exact expression where the variable is referenced

    // Assignment reference Check
    // DEF assrefs_: HashMap of variables who are referenced in an assignment(left) but not 
    // initialized yet, with mapping to the exact expression where the variable is referenced
    // we don't know yet whether we have to initialize assrefs, we add them into references that
    // have to be initialized when we leave a function (or main)

    // Mutation Check
    // DEF tmpInits_: HashMap of references and nodes where the reference is invoked at the nodes
    // and refrences are "temporaryly" considered as initializations of the variable in some branch 
    // in this scope
    // This means that the elements from tmpInits might change its state and join mutated at some
    // point in the future if the variable is initialized above in the code
    // DEF mutated : HashMap of references and nodes where the reference is invoked at the nodes
    // and variable (to which the refernce points) is mutated  

    public init() {
        inits_= HashSet<Reference>()
        tmpInits_ = HashMap<Reference, ArrayList<Node>>()
        refs_ = HashMap<Reference, ArrayList<Node>>()
        assrefs_ = HashMap<Reference, ArrayList<Node>>()
        mutated_ = HashMap<Reference, ArrayList<Node>>()
    }
    
    public init(inits: HashSet<Reference>, tmpInits: HashMap<Reference, ArrayList<Node>>, 
                refs: HashMap<Reference, ArrayList<Node>>, 
                assrefs: HashMap<Reference, ArrayList<Node>>, 
                mutated: HashMap<Reference, ArrayList<Node>> ) {
        inits_ = inits
        tmpInits_ = tmpInits
        refs_ = refs
        assrefs_ = assrefs
        mutated_ = mutated
    }

    /* Do not modify */
    private func merge<T>(setA_:HashSet<T>, setB_: HashSet<T>) : 
            (HashSet<T>, HashSet<T>, HashSet<T>) where T <: Hashable & Equatable<T> {
        let (setA, setB) = sswap(setA_, setB_)
        let arrA = setA.toArray()
        setB.add(all: arrA)
        let intersection = HashSet<T>()
        arrA.iterator().forEach({d => 
            if(setB.contains(d)){
                intersection.add(d)
            }
        })
        setA.clear()

        (setB, setA, intersection)
    }

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

    private func cancelInitlaizedReferences<T, V>(someSet: HashSet<T>, 
                someMap: HashMap<T, ArrayList<V>>) :
                (HashMap<T, ArrayList<V>>, HashMap<T, ArrayList<V>>) 
                where T <: Hashable & Equatable<T> {
        let intersection = HashMap<T, ArrayList<V>>()
        if(someSet.size > someMap.size) {
            let arr = someMap.toArray()
            for(entry in arr) {
                let (ref, nodeList) = entry
                if(someSet.contains(ref)) {
                    intersection.add(ref, nodeList)
                    someMap.remove(ref)
                }
            }
        } else {
            let arr = someSet.toArray()
            for(entry in arr){
                let ref = entry
                if(let Some(nodeList) <- someMap.get(ref)) {
                    someMap.remove(ref)
                    intersection.add(ref, nodeList)
                }
            }
        }

        (someMap, intersection)
    }

    public func merge(other: InitsRefs, newMutated: HashMap<Reference, ArrayList<Node>>) {
        (inits, other.inits, _) = merge(inits, other.inits)
        (tmpInits, other.tmpInits) = merge(tmpInits, other.tmpInits)
        (refs,  other.refs) =  merge(refs, other.refs)
        (assrefs, other.assrefs) = merge(assrefs, other.assrefs)

        (mutated, _) = merge(mutated, newMutated)
        (mutated, other.mutated) = merge(mutated, other.mutated)
    }

    public func seqMerge<T, V>(inits: HashSet<T>, refs: HashMap<T, ArrayList<V>>, 
                assrefs: HashMap<T, ArrayList<V>>, tmpInits: HashMap<T, ArrayList<V>>) 
                where T <: Hashable & Equatable<T> {
        let (newRefs, _) = cancelInitlaizedReferences(inits, refs)
        let (newAssrefs, _) = cancelInitlaizedReferences(inits, assrefs)
        let (newTmpInits, newMutated) = cancelInitlaizedReferences(inits, tmpInits)
        (newRefs, newAssrefs, newTmpInits, newMutated)
    }

    // Merging with other InitsRefs
    public func mergeL(other: InitsRefs) {
        var newMutated = HashMap<Reference, ArrayList<Node>>()
        (other.refs, other.assrefs, other.tmpInits, newMutated) = 
            seqMerge(inits, other.refs, other.assrefs, other.tmpInits)
        merge(other, newMutated)
    }
    public func mergeR(other: InitsRefs) {
        var newMutated = HashMap<Reference, ArrayList<Node>>()
        (refs, assrefs, tmpInits, newMutated) = 
            seqMerge(other.inits, refs, assrefs, tmpInits)
        merge(other, newMutated)
    }
    public func branchMerge(other: InitsRefs) {
        (_, other.inits, inits) = merge(inits, other.inits)
        merge(other, HashMap<Reference, ArrayList<Node>>())
    }

    // Editing and Asking information about reference or initialization of variables
    public func initialized(ref: Reference, node: Node) {
        tmpInits.add(ref, ArrayList<Node>([node]))
        inits.add(ref)
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
        // (mutated, tmpInits) = merge(mutated, tmpInits)
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

    private mut prop inits: HashSet<Reference> {
        get() { inits_ }
        set(v) { inits_ = v }
    }

    private mut prop tmpInits: HashMap<Reference, ArrayList<Node>> {
        get() { tmpInits_ }
        set(v) { tmpInits_ = v }
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

