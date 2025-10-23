package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.parser.NodeIdManager
import cjcj.scanner.TokenKind
import cjcj.scanner.Token
import cjcj.asg.*

import std.collection.*
import std.deriving.Derive
import stdx.effect.Command
import std.ast.Position

@Derive[Equatable]
public enum Status {
    IN | VIS
}

public class TypeInfoBus <: Command<Bool> {
    TypeInfoBus(public let name: String, public let ref: Reference) {}
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
    private let topOrder = ArrayList<Reference>()
    private let status: Map<Reference, Status> = HashMap()

    /*
    * Creates and returns:
    *   - the typeManager filled with all the type declarations.
    *   - the list of class references of the program in topological order of inheritance.
    */
    public func resolve(program: Program): (TypeManager, Array<Reference>) {
        let typeManager: TypeManager = TypeManager()
        BUILTIN_INTERFACES.iterator().forEach({ entry => 
            let ref = entry[0]
            topOrder.add(ref)
            status.add(ref, Status.VIS)
            declTypes.add(ref.identifier.value, ref)
        })
        BUILTIN_CLASSES.iterator().forEach({ entry => 
            let ref = entry[0]
            topOrder.add(ref)
            status.add(ref, Status.VIS)
            declTypes.add(ref.identifier.value, ref)
        })
        try {
            program.traverse(this)
        } handle(typeInfo: TypeInfoBus) {
            declTypes.add(typeInfo.name, typeInfo.ref)
            resume with false
        }

        try {
            program.traverse(this)
        } handle(_: TypeInfoBus) {
            resume with true
        }

        topOrder.iterator().forEach({ t => 
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
        (typeManager, topOrder.toArray())
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

    public override func visit(program: Program): Unit {
        program.decls.iterator().forEach({ d => d.traverse(this) })
    }

    public override func visit(classRef: ClassReference): Unit {
        if (let Some(status) <- status.get(classRef)) {
            match(status) {
                case Status.IN => throw Exception("Cyclic type inheritance")
                case _ => return
            }
        }

        if (let Some(parent) <- classRef.parent) {
            declTypes.get(parent.identifier.value).getOrThrow({ => 
                Exception("Undeclared type ${parent.identifier.value}")}).traverse(this)
        }

        classRef.parentInterfaces.iterator().forEach({ interfaceRef => 
            declTypes.get(interfaceRef.identifier.value).getOrThrow({ => 
                Exception("Undeclared type ${interfaceRef.identifier.value}")
            }).traverse(this)
        })

        status.add(classRef, Status.VIS)
        topOrder.add(classRef)
    }

    public override func visit(interfaceRef: InterfaceReference): Unit {
        if (let Some(status) <- status.get(interfaceRef)) {
            match(status) {
                case Status.IN => throw Exception("Cyclic type inheritance")
                case _ => return
            }
        }

        interfaceRef.parents.iterator().forEach({ interfaceRef => 
            declTypes.get(interfaceRef.identifier.value).getOrThrow({ => 
                Exception("Undeclared type ${interfaceRef.identifier.value}")
            }).traverse(this)
        })

        status.add(interfaceRef, Status.VIS)
        topOrder.add(interfaceRef)
    }

    public override func visit(classDecl: ClassDeclWithRef) {
        if (perform TypeInfoBus(classDecl.identifier.value, classDecl.ref)) {
            classDecl.ref.traverse(this)
        }
    }

    public override func visit(interfaceDecl: InterfaceDeclWithRef) {
        if (perform TypeInfoBus(interfaceDecl.identifier.value, interfaceDecl.ref)) {
            interfaceDecl.ref.traverse(this)
        }
    }

    public override func visit(_: VarDeclWithRef): Unit{ }

    public override func visit(_: FuncDeclWithRef): Unit{ }

    public override func visit(_: MainDeclWithRef): Unit{ }
}

