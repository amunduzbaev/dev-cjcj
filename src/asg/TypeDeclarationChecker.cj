package cjcj.asg

import cjcj.visitor.*
import cjcj.parser.NodeIdManager
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

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
    private let declTypes: Map<String, ClassReference> = HashMap()
    private let edges: Map<Reference, String> = HashMap()
    private let refToDecl: Map<Reference, Decl> = HashMap()

    /*
    * Creates and returns:
    *   - the typeManager filled with all the type declarations.
    *   - the list of class references of the program in topological order of inheritance.
    */
    public func resolve(program: Program): (TypeManager, Array<ClassReference>, Map<Reference, Decl>) {
        let typeManager: TypeManager = TypeManager()
        declareBuiltinTypes()
        program.traverse(this)
        let toposort: Array<ClassReference> = toposort(declTypes)
        toposort.iterator().forEach({ t => typeManager.addType(t.identifier.value, match(t.parent) {
            case Some(p) => ArrayList([p.identifier.value])
            case _ => ArrayList()
        }, isOpen: t.isOpen) })
        // After I have added all types I can add the builtin functions.
        defineBuiltinFunctions(typeManager)
        (typeManager, toposort, refToDecl)
    }

    private func declareBuiltinTypes() {
        BUILTIN_TYPES.iterator().map<(String, ClassReference)>({ v: (String, Array<String>) =>
            let ref = ClassReference(
                NodeIdManager.nextId(), Token(TokenKind.ILLEGAL, v[0], Position()), true)
            v[1].iterator().forEach({ p => edges.add(ref, p) })
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

    private func toposort(graph: Map<String, ClassReference>): Array<ClassReference> {
        let sort: ArrayList<ClassReference> = ArrayList()
        let status: Map<Reference, Status> = HashMap()
        for ((name, classReference) in graph) {
            if (!status.contains(classReference)) {
                dfs(classReference, graph, status, sort)
            }
        }
        sort.toArray()
    }

    private func dfs(current: ClassReference, graph: Map<String, ClassReference>,
        status: Map<Reference, Status>, sort: ArrayList<ClassReference>): Unit
    {
        if (let Some(status) <- status.get(current)) {
            match(status) {
                case Status.IN => throw Exception("Cyclic type inheritance")
                case _ => return
            }
        }
        status.add(current, Status.IN)
        if (let Some(parent) <- edges.get(current)) {
            current.parent = graph.get(parent).getOrThrow()
        }
        if (let Some(parent) <- current.parent) {
            dfs(
                graph.get(parent.identifier.value).getOrThrow({ =>
                    Exception("Type ${parent} doesn't exist")
                }),
                graph, status, sort
            )
        }
        status.add(current, Status.VIS)
        sort.add(current)
    }

    public override func visit(program: Program): Unit  {
        program.decls.iterator().forEach({ d => d.traverse(this) })
    }

    // I only want to visit declarations of new types, I can skip everything else.
    public override func visit(classDecl: ClassDecl): Unit {
        let ref: ClassReference = ClassReference(NodeIdManager.nextId(), classDecl.identifier, true)
        refToDecl.add(ref, classDecl)
        if (classDecl.superTypes.isEmpty()) {
            edges.add(ref, "Object")
        } else if (
            classDecl.superTypes.size == 1 &&
            let Some(superClass) <- classDecl.superTypes.get(0)
        ) {
            edges.add(ref, superClass.typeName.value)
        } else {
            throw Exception("Invalid number of superclasses, it can be max 1.")
        }

        if (let Some(_) <- declTypes.addIfAbsent(classDecl.identifier.value, ref)) {
            throw Exception("Redefined type ${classDecl.identifier.value}")
        }
    }

    public override func visit(_: VarDecl): Unit{ }

    public override func visit(_: FuncDecl): Unit{ }

    public override func visit(_: MainDecl): Unit{ }
}