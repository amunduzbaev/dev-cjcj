package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.parser.NodeIdManager
import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.ast.Position
import std.collection.*

/*
* Used to represent a type of which we don't know all the information needed, for example we may not
* know if the parents exist, so this class will take only the names and assume that everything is
* fine and exists without any check.
*/
private class TypePrecursor <: Equatable<TypePrecursor> & Hashable {
    private let name_: String
    private let parents_: ArrayList<String>
    private let isOpen_: Bool

    public init(name: String, parents: ArrayList<String>) {
        this(name, parents.toArray(), false)
    }

    public init(name: String, parents: ArrayList<String>, isOpen: Bool) {
        this(name, parents.toArray(), isOpen)
    }

    public init(name: String, parents: Array<String>) {
        this(name, parents, false)
    }

    public init(name: String, parents: Array<String>, isOpen: Bool) {
        name_ = name
        parents_ = parents.iterator().fold(ArrayList(), { r, t => r.add(t); r })
        isOpen_ = isOpen
    }

    public override operator func ==(other: TypePrecursor): Bool {
        this.name == other.name
    }

    public override operator func !=(other: TypePrecursor): Bool {
        this.name != other.name
    }

    public override func hashCode(): Int64 {
        name.hashCode()
    }

    public prop name: String {
        get() { name_ }
    }

    public prop parents: ArrayList<String> {
        get() { parents_ }
    }

    public prop isOpen: Bool {
        get() { isOpen_ }
    }
}

// TODO: Maybe create a generic Graph class that contains all the graph functions.
private enum Status {
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
    // TODO: Add all builtin functions and types (make a script to do that).
    private static let BUILTIN_FUNCTIONS:
        ArrayList<(String, ArrayList<(ArrayList<String>, String)>)> = ArrayList([
            ("+", ArrayList([
                (ArrayList(["Int64", "Int64"]), "Int64"),
                (ArrayList(["Int32", "Int32"]), "Int32")
            ]))
        ])

    // TODO: Fix this, for exampe Int64 is <: ToString & Hashable and others probably. For now I
    // assume that it's just <: Any
    private static let BUILTIN_TYPES: Array<(String, Array<String>)> = [
        ("Int64", ["Any"]), ("Int32", ["Any"]), ("Int16", ["Any"]), ("Int8", ["Any"]),
        ("IntNative", ["Any"]),  ("UInt64", ["Any"]), ("UInt32", ["Any"]), ("UInt16", ["Any"]),
        ("UInt8", ["Any"]), ("UIntNative", ["Any"]), ("Float64", ["Any"]), ("Float32", ["Any"]),
        ("Float16", ["Any"]), ("Rune", ["Any"]), ("Unit", ["Any"]), ("Bool", ["Any"]),
        ("Nothing", ["Any"]), ("String", ["Any"]), ("Object", ["Any"]), ("Any", [])
    ]

    private let declTypes: Map<String, TypePrecursor> = HashMap()

    // Creates and returnes the typeManager filled with all the type declarations.
    public func resolve(program: Program): TypeManager {
        let typeManager: TypeManager = TypeManager()
        declareBuiltinTypes()
        program.traverse(this)
        let toposort: Array<TypePrecursor> = toposort(declTypes)
        toposort.iterator().forEach({t => typeManager.addType(t.name, t.parents, isOpen: t.isOpen)})
        // After I have added all types I can add the builtin functions.
        defineBuiltinFunctions(typeManager)
        typeManager
    }

    private func declareBuiltinTypes() {
        BUILTIN_TYPES.iterator().map<(String, TypePrecursor)>({ v =>
            (v[0], TypePrecursor(v[0], v[1], true))
        }).forEach({ v: (String, TypePrecursor) => declTypes.add(v[0], v[1]) })
    }

    private func defineBuiltinFunctions(typeManager: TypeManager) {
        BUILTIN_FUNCTIONS.iterator()
            .map({ v: (String, ArrayList<(ArrayList<String>, String)>) => (
                v[0],
                v[1].iterator().map({ v: (ArrayList<String>, String) => (
                    v[0].iterator().map({ v => typeManager.get(v) })
                        .fold<ArrayList<Type>>(ArrayList(), { res, v => res.add(v); res }),
                    typeManager.get(v[1])
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

    private func toposort(graph: Map<String, TypePrecursor>): Array<TypePrecursor> {
        let sort: ArrayList<TypePrecursor> = ArrayList()
        let status: Map<TypePrecursor, Status> = HashMap()
        for ((name, typePrecursor) in graph) {
            if (!status.contains(typePrecursor)) {
                dfs(typePrecursor, graph, status, sort)
            }
        }
        sort.toArray()
    }

    private func dfs(current: TypePrecursor, graph: Map<String, TypePrecursor>,
        status: Map<TypePrecursor, Status>, sort: ArrayList<TypePrecursor>): Unit
    {
        if (let Some(status) <- status.get(current)) {
            match(status) {
                case Status.IN => throw Exception("The type graph is not a DAG")
                case _ => return
            }
        }
        status.add(current, Status.IN)
        for (parent in current.parents) {
            dfs(graph.get(parent).getOrThrow({ => Exception("Type ${parent} doesn't exist")}),
                graph, status, sort)
        }
        status.add(current, Status.VIS)
        sort.add(current)
    }

    public override func visit(program: Program): Unit  {
        program.decls.iterator().forEach({ d => d.traverse(this) })
    }

    // I only want to visit declarations of new types, I can skip everything else.
    public override func visit(classDecl: ClassDeclWithRef): Unit {
        let supertypes: ArrayList<String> = classDecl.superTypes.iterator()
            .map({ st => st.typeName.value })
            .fold<ArrayList<String>>(ArrayList(), { res, v => res.add(v); res })
        
        declTypes.add(classDecl.identifier.value,
            TypePrecursor(classDecl.identifier.value,
                // TODO: Desugar classes without supertypes to be <: Object
                supertypes,
                true
            )
        )
    }
 
    public override func visit(_: BinaryExpr): Unit { }

    public override func visit(_: UnaryExpr): Unit { }

    public override func visit(_: ParenExpr): Unit { }

    public override func visit(_: LitConstExpr): Unit { }

    public override func visit(_: AssignExpr): Unit { }

    public override func visit(_: RefExpr): Unit { }

    public override func visit(_: Block): Unit { }

    public override func visit(_: IfExpr): Unit { }

    public override func visit(_: WhileExpr): Unit { }

    public override func visit(_: CallExpr): Unit { }

    public override func visit(_: ReturnExpr): Unit { }

    public override func visit(_: VarDecl): Unit { }

    public override func visit(_: FuncParam): Unit { }

    public override func visit(_: FuncDecl): Unit { }

    public override func visit(_: MainDecl): Unit { }

    public override func visit(_: Argument): Unit { }

    public override func visit(_: TypeNode): Unit { }

    public override func visit(_: PrimitiveType): Unit { }

    public override func visit(_: RefType): Unit { }

    public override func visit(_: VariableReference): Unit { }

    public override func visit(_: FuncReference): Unit{ }

    public override func visit(_: VarDeclWithRef): Unit{ }

    public override func visit(_: FuncDeclWithRef): Unit{ }

    public override func visit(_: MainDeclWithRef): Unit{ }
}