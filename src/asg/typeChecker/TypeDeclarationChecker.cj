package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.parser.NodeIdManager
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.asg.TypeManager
import cjcj.asg.Utils

import std.ast.Position
import std.collection.*
import std.deriving.Derive

// TODO: Maybe create a generic Graph class that contains all the graph functions.
@Derive[Equatable]
public enum Status {
    IN | VIS
}

/*
* Will traverse the ASG, declare every type and check that the type declarations are ok, i.e. that
* every type is declared at most once (In the future we will implement visibility and package checks
* for this issue, right now we will just look at the type name), that all the ancestors of a type
* are valid inheritable types (either class, struct with the open / abstract keyword or interfaces)
* and that there are not cyclic inheritance.
* After that we will create the DAG of the types to make the future checks easier.
*/

public class TypeDeclarationChecker <: Visitor<Unit> {
    private let declTypes: Map<String, Reference> = HashMap()
    private let edges: Map<Reference, ArrayList<String>> = HashMap()

    /*
    * Creates and returns:
    *   - the typeManager filled with all the type declarations.
    *   - the list of class references of the program in topological order of inheritance.
    */
    public func resolve(program: Program): (TypeManager, Array<Reference>) {
        let typeManager: TypeManager = TypeManager()
        declareBuiltinTypes()
        program.traverse(this)
        let toposort: Array<Reference> = toposort(declTypes)

        toposort.iterator().forEach({ t => 
            let isOpen = match (t as ClassReference) {
                case Some(classRef) => classRef.isOpen
                case _ => true
            }
            let parents = match (t as ClassReference) {
                case Some(classRef) => 
                    let arr = match (classRef.parent) {
                        case Some(p) => ArrayList([p.identifier.value])
                        case _ => ArrayList<String>()
                    }
                    Utils.fold((classRef.parentInterfaces.iterator().map({i => i.identifier.value})),
                        arr)
                case _ => 
                match (t as InterfaceReference) {
                    case Some(interfaceRef) => 
                        Utils.fold(interfaceRef.parents.iterator().map({i => i.identifier.value}), 
                            ArrayList<String>())
                    case _ => ArrayList<String>()
                }
            }
            typeManager.addType(t.identifier.value, parents, isOpen: isOpen)
        })
        // After I have added all types I can add the builtin functions.
        defineBuiltinFunctions(typeManager)
        (typeManager, toposort)
    }

    // TODO : Fix Declaration of Builtin Types. Not all are classes, some are interfaces
    private func declareBuiltinTypes() {
        BUILTIN_TYPES.iterator().map<(String, ClassReference)>({ v: (String, Array<String>) =>
            let ref = ClassReference(
                NodeIdManager.nextId(), Token(TokenKind.ILLEGAL, v[0], Position()), true)
            v[1].iterator().forEach({ p => addEdge(ref, p) })
            (v[0], ref)
        }).forEach({ v: (String, ClassReference) => declTypes.add(v[0], v[1]) })
    }

    private func defineBuiltinFunctions(typeManager: TypeManager) {
        BUILTIN_FUNCTIONS.iterator()
            .map({ v: (String, ArrayList<(ArrayList<String>, String)>) => (
                v[0],
                v[1].iterator().map<(ArrayList<Type>, Type)>({ v: (ArrayList<String>, String) => (
                    Utils.fold(v[0].iterator().map({ v => typeManager.getType(v) }), ArrayList()),
                    typeManager.getType(v[1])
                )}))
            }).forEach({ v => v[1].iterator().forEach({ t =>
                // Create a reference for each parameter and then create the func reference to pass.
                let paramRef: ArrayList<VariableReference> = t[0].iterator()
                    .fold(ArrayList(), { acc, v =>
                        let ref: VariableReference = VariableReference(NodeIdManager.nextId(),
                            Token(), Token(TokenKind.LET, "let", Position()))
                        ref.effectiveType = v
                        acc.add(ref); acc
                    })

                let ref = FuncReference(NodeIdManager.nextId(),
                    Token(TokenKind.ILLEGAL, v[0], Position()))
                ref.paramRef = paramRef
                ref.effectiveType = t[1]
                typeManager.addFunction(ref)
            })
        })
    }

    private func toposort(graph: Map<String, Reference>): Array<Reference> {
        let sort: ArrayList<Reference> = ArrayList()
        let status: Map<Reference, Status> = HashMap()
        for ((name, classReference) in graph) {
            if (!status.contains(classReference)) {
                dfs(classReference, graph, status, sort)
            }
        }
        sort.toArray()
    }

    // Fix DFS
    private func dfs(current: Reference, graph: Map<String, Reference>,
        status: Map<Reference, Status>, sort: ArrayList<Reference>): Unit
    {
        match (current as ClassReference) {
            case Some(current) => 
                if (let Some(parents) <- edges.get(current) && let Some(parent) <- parents.get(0)) {
                    let parentRef = graph.get(parent).getOrThrow()
                    match (parentRef as ClassReference) {
                        case Some(parent) => current.parent = parent
                        case _ => ()
                    }
                }
            case _ => ()
        }

        if (let Some(status) <- status.get(current)) {
            match(status) {
                case Status.IN => throw Exception("Cyclic type inheritance")
                case _ => return
            }
        }
        status.add(current, Status.IN)
        if (let Some(parents) <- edges.get(current)) {
            parents.iterator().forEach({ parent => 
                dfs(
                    graph.get(parent).getOrThrow({ =>
                        Exception("Type ${parent} doesn't exist")
                    }),
                    graph, status, sort
                )
            })
        }
        status.add(current, Status.VIS)
        sort.add(current)
    }

    private func addEdge(subTypeRef: Reference, superTypeName: String) {
        let singleSuperType = Utils.fold([superTypeName].iterator(), ArrayList<String>())
        if (let Some(superTypes) <- edges.addIfAbsent(subTypeRef, singleSuperType)) {
            superTypes.add(superTypeName)
            edges.add(subTypeRef, superTypes)
        }
    }

    public override func visit(program: Program): Unit  {
        program.decls.iterator().forEach({ d => d.traverse(this) })
    }

    // I only want to visit declarations of new types, I can skip everything else.
    // UPD : upon the addition of interfaces, classes can have multiple super types. 
    // TODO : The enforcement of the rule that classes can have at most superclass and interfaces 
    // can not have super classes must be done
    public override func visit(classDeclWithRef: ClassDeclWithRef): Unit {
        if (classDeclWithRef.superTypes.isEmpty()) {
            addEdge(classDeclWithRef.ref, "Object")
        } else {
            let addedSuperTypes = HashSet<String>()
            classDeclWithRef.superTypes.iterator().forEach{ superType => 
                addEdge(classDeclWithRef.ref, superType.typeName.value)
                if (addedSuperTypes.contains(superType.typeName.value)) {
                    throw Exception("class ${classDeclWithRef.identifier.value} implements " + 
                        "multiple super types ${superType.typeName.value}")
                }
            }
        } 

        declTypes.add(classDeclWithRef.identifier.value, classDeclWithRef.ref)
    }

    public override func visit(interfaceDeclWithRef: InterfaceDeclWithRef): Unit {
        if (interfaceDeclWithRef.superTypes.isEmpty()) {
            addEdge(interfaceDeclWithRef.ref, "Any")
        } else {
            let addedSuperTypes = HashSet<String>()
            interfaceDeclWithRef.superTypes.iterator().forEach{ superType => 
                addEdge(interfaceDeclWithRef.ref, superType.typeName.value)
                if (addedSuperTypes.contains(superType.typeName.value)) {
                    throw Exception("class ${interfaceDeclWithRef.identifier.value} implements " + 
                        "multiple super types ${superType.typeName.value}")
                }
            }
        }

        declTypes.add(interfaceDeclWithRef.identifier.value, interfaceDeclWithRef.ref)
    }

    public override func visit(_: VarDeclWithRef): Unit{ }

    public override func visit(_: FuncDeclWithRef): Unit{ }

    public override func visit(_: MainDeclWithRef): Unit{ }
}

