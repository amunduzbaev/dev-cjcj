package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.asg.TypeManager
import cjcj.asg.Declarator
import cjcj.asg.DeclaratorFactory
import cjcj.asg.Utils
import cjcj.scanner.Token
import cjcj.parser.NodeIdManager
import cjcj.asg.VisitorEffect
import std.collection.*

/*
 * It will check that all the operation types and assignments are correct based on the types of the
 * elements and based on the defined operations.
 * It will visit all the graph and will try to assign types to all the declarations, if a declaration
 * has a declaration type 't' it will check if the inferred type of the assignment or the block is a
 * subtype of 't'.
 * If it encounters a variable reference or a function call and there is no declaration type it will
 * go to the declaration and solve it. If there are cycles or a type cannot be inferred it will throw
 * an exception.
 */
public class TypeChecker <: Visitor<Unit> {
    // Used to know if there are cycles.
    private let referenceStatus: Map<Reference, Status> = HashMap()

    // Maps the reference to the declaration.
    private let refToDecl: Map<Reference, Decl> = HashMap()
    private let declToTypeManager: Map<Decl, TypeManager> = HashMap()

    private var typeManager: TypeManager

    // For member access and operations inside the class
    // public let classEnvironment: Environment<String, ClassReferenceForTC> = Environment()
    private var currentMembersContainer: ?MembersContainer = None
    public let typeEnvironment: Environment<String, MembersContainer> = Environment()

    // Contains the name of the last callable field if there is some.
    // private var callableField: ?String = None

    // TODO: Maybe make a map of Nodes directly.
    private let nodePossibleTypes: Map<NodeId, Set<Type>> = HashMap()
    private let typeAssigner: TypeAssigner
    private let functionTypeGrouping: Map<NodeId, Map<Type, ?FuncReference>> = HashMap()

    public init(program: Program) {
        // Declare every type.
        let typesTopoOrder: Array<Reference>
        (typeManager, typesTopoOrder) = TypeDeclarationChecker().resolve(program)
        typeAssigner = TypeAssigner(
            nodePossibleTypes,
            typeEnvironment,
            typeManager,
            functionTypeGrouping
        )

        typesTopoOrder.iterator().forEach({
            ref => match (ref as ClassReference) {
                case Some(classRef) =>
                    let parentRefForTC: ?MembersContainer = match (classRef.parent) {
                        case Some(parent) => typeEnvironment.getLocal(parent.identifier.value)
                        case _ => None
                    }
                    let membersContainer = MembersContainer(classRef, parentRefForTC)
                    membersContainer.typeManager = TypeManager(typeManager)
                    typeEnvironment.declare(classRef.identifier.value, membersContainer)
                case _ => match (ref as InterfaceReference) {
                    case Some(interfaceRef) =>
                        let membersContainer = MembersContainer(interfaceRef, None)
                        membersContainer.typeManager = TypeManager(typeManager)
                        typeEnvironment.declare(interfaceRef.identifier.value, membersContainer)
                    case _ => ()
                }
            }
        })

        let globalAsgDeclarator: Declarator = DeclaratorFactory.globalAsgDeclarator(
            Environment(),
            Environment(),
            typeManager,
            refToDecl,
            declToTypeManager
        )
        program.decls.iterator().forEach({d => d.traverse(globalAsgDeclarator)})
        // Declare the body of classes and interfaces
        program.decls.iterator().filter({d => d is ClassDeclWithRef || d is InterfaceDeclWithRef}).forEach(
            {
                d =>
                    let membersContainer = typeEnvironment
                        .getGlobal(d.identifier.value)
                        .getOrThrow({=> Exception("Unexpected, class should've been declared")})

                    let variableEnvironment: Environment<String, VariableReference> = Environment()
                    let bodyTypeManager = membersContainer.typeManager.getOrThrow()

                    membersContainer.typeManager = bodyTypeManager
                    membersContainer.variableEnvironment = variableEnvironment

                    let bodyOwnerDeclarator: Declarator = DeclaratorFactory.bodyAsgDeclarator(variableEnvironment,
                        bodyTypeManager, refToDecl, declToTypeManager)
                    d.traverse(bodyOwnerDeclarator)
            }
        )

        // Add empty init to all the classes that don't have one.
        typeEnvironment
            .elements
            .values()
            .iterator()
            .filter({tp => tp.typeReference is ClassReference})
            .map<(String, TypeManager)>({
                c => (c.typeReference.identifier.value, c.typeManager.getOrThrow())
            })
            .filter({t => !t[1].funcExists("")})
            .forEach(
                {
                    t =>
                        let ref: FuncReference = FuncReference(NodeIdManager.nextId(), Token())
                        ref.effectiveType = typeManager.getType(t[0])
                        ref.paramRef = ArrayList()
                        t[1].addFunction(ref)
                        nodePossibleTypes.add(ref.id, HashSet([ref.effectiveType.getOrThrow()]))
                }
            )

        program.decls.iterator().forEach({d => d.traverse(this)})
    }

    public override func visit(program: Program): Unit {
        program.decls.iterator().forEach({d => d.traverse(this)})
    }

    public override func visit(binaryExpr: BinaryExpr): Unit {
        binaryExpr.left.traverse(this)
        let leftTypes: Set<Type> = nodePossibleTypes[binaryExpr.left.id]

        binaryExpr.right.traverse(this)
        let rightTypes: Set<Type> = nodePossibleTypes[binaryExpr.right.id]

        let typeGrouping: Map<Type, ?FuncReference> = typeManager.applyFunction(binaryExpr.oper.value,
            [leftTypes, rightTypes], None)

        functionTypeGrouping.add(binaryExpr.id, typeGrouping)
        nodePossibleTypes.add(binaryExpr.id, HashSet(typeGrouping.keys()))
    }

    public override func visit(unaryExpr: UnaryExpr): Unit {
        unaryExpr.right.traverse(this)
        let rightTypes: Set<Type> = nodePossibleTypes[unaryExpr.right.id]

        let typeGrouping: Map<Type, ?FuncReference> = typeManager.applyFunction(unaryExpr.oper.value, [rightTypes], None)

        functionTypeGrouping.add(unaryExpr.id, typeGrouping)
        nodePossibleTypes.add(unaryExpr.id, HashSet(typeGrouping.keys()))
    }

    public override func visit(parenExpr: ParenExpr): Unit {
        parenExpr.parenthesizedExpr.traverse(this)
        nodePossibleTypes.add(parenExpr.id, nodePossibleTypes[parenExpr.parenthesizedExpr.id])
    }

    public override func visit(litConstExpr: LitConstExpr): Unit {
        nodePossibleTypes.add(
            litConstExpr.id,
            HashSet(match (litConstExpr.literal.kind) {
                // TODO: Change this, compiler can do implicit cast.
                case TokenKind.INTEGER_LITERAL => [
                    typeManager.getType("Int64"),
                    typeManager.getType("Int32"),
                    typeManager.getType("Int16"),
                    typeManager.getType("Int8"),
                    typeManager.getType("IntNative"),
                    typeManager.getType("UInt64"),
                    typeManager.getType("UInt32"),
                    typeManager.getType("UInt16"),
                    typeManager.getType("UInt8"),
                    typeManager.getType("UIntNative"),
                    typeManager.getType("Hashable"),
                    typeManager.getType("ToString"),
                    typeManager.getType("Any")
                ]
                case TokenKind.FLOAT_LITERAL => [
                    typeManager.getType("Float64"),
                    typeManager.getType("Float32"),
                    typeManager.getType("Float16"),
                    typeManager.getType("Hashable"),
                    typeManager.getType("ToString"),
                    typeManager.getType("Any")
                ]
                case TokenKind.BOOL_LITERAL => [
                    typeManager.getType("Bool"),
                    typeManager.getType("Hashable"),
                    typeManager.getType("ToString"),
                    typeManager.getType("Any")
                ]
                case TokenKind.STRING_LITERAL => [
                    typeManager.getType("String"),
                    typeManager.getType("Hashable"),
                    typeManager.getType("ToString"),
                    typeManager.getType("Any")
                ]
                case TokenKind.UNIT_LITERAL => [
                    Type.UNIT,
                    typeManager.getType("Hashable"),
                    typeManager.getType("ToString"),
                    typeManager.getType("Any")
                ]
                // TODO: Add all other literals.
                case _ => throw Exception("You forgot to add all the literal types")
            })
        )
    }

    public override func visit(assignExpr: AssignExpr): Unit {
        assignExpr.left.traverse(this)
        assignExpr.right.traverse(this)
        nodePossibleTypes.add(assignExpr.id, Type.UNIT.ancestorSet)
    }

    public override func visit(block: Block): Unit {
        beginScope()

        // TODO: We don't actually need to do this here, remove it to optimize.
        let lastId = block.nodes.last.getOrDefault({=> Expr()}).id
        try {
            block.nodes.iterator().forEach({n => n.traverse(this)})
        } handle (_: CallableFieldBus) {
            resume with ()
        }

        endScope()
        nodePossibleTypes.add(block.id, nodePossibleTypes.get(lastId).getOrDefault({=> Type.UNIT.ancestorSet}))
    }

    public override func visit(ifExpr: IfExpr): Unit {
        ifExpr.condition.traverse(this)
        ifExpr.ifBlock.traverse(this)
        ifExpr.elseBranch.traverse(this)

        let myTypes: Set<Type> = HashSet()
        nodePossibleTypes[ifExpr.ifBlock.id].iterator().forEach({
            t1 => nodePossibleTypes[ifExpr.ifBlock.id].iterator().forEach({
                t2 =>
                // Add all the common supertypes of t1 and t2.
                myTypes.add(all: typeManager.smallestCommonSupertypeSet(t1, t2))
            })
        })
        nodePossibleTypes.add(ifExpr.id, myTypes)
    }

    public override func visit(whileExpr: WhileExpr): Unit {
        whileExpr.condition.traverse(this)
        whileExpr.block.traverse(this)
        nodePossibleTypes.add(whileExpr.id, Type.UNIT.ancestorSet)
    }

    public override func visit(returnExpr: ReturnExpr): Unit {
        if (let Some(expr) <- returnExpr.expr) {
            expr.traverse(this)
        }
        nodePossibleTypes.add(returnExpr.id, HashSet([Type.NOTHING]))
    }

    public override func visit(funcParam: FuncParam): Unit {
        funcParam.paramType.traverse(this)
        nodePossibleTypes.add(funcParam.id, nodePossibleTypes[funcParam.paramType.id])
    }

    public override func visit(argument: Argument): Unit {
        argument.expr.traverse(this)
        nodePossibleTypes.add(argument.id, nodePossibleTypes[argument.expr.id])
    }

    public override func visit(primitiveType: PrimitiveType): Unit {
        nodePossibleTypes.add(primitiveType.id, HashSet([typeManager.getType(primitiveType.typeName.value)]))
    }

    public override func visit(refType: RefType): Unit {
        nodePossibleTypes.add(refType.id, HashSet([typeManager.getType(refType.typeName.value)]))
    }

    public override func visit(varDeclWithRef: VarDeclWithRef): Unit {
        let ref: Reference = varDeclWithRef.ref
        if (let Some(status) <- referenceStatus.get(ref)) {
            match (status) {
                case Status.IN => throw Exception("Could not infer the type of " + "${ref.identifier.value}")
                case Status.VIS => return
            }
        }
        referenceStatus.add(ref, Status.IN)

        if (let Some(declType) <- varDeclWithRef.declType) {
            nodePossibleTypes.add(ref.id, HashSet([declType.traverse(typeAssigner)]))
        }

        if (let Some(initzer) <- varDeclWithRef.initializer) {
            initzer.traverse(this)
            if (nodePossibleTypes.get(ref.id).isNone()) {
                nodePossibleTypes.add(ref.id, nodePossibleTypes[initzer.id])
            }
        }

        referenceStatus.add(ref, Status.VIS)
        nodePossibleTypes.add(varDeclWithRef.id, HashSet([varDeclWithRef.traverse(typeAssigner)]))
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): Unit {
        let precTypeManager: TypeManager = typeManager
        typeManager = if (let Some(declTypeManager) <- declToTypeManager.get(funcDeclWithRef)) {
            declTypeManager
        } else {
            typeManager
        }

        let ref: FuncReference = funcDeclWithRef.funcRef
        if (let Some(status) <- referenceStatus.get(ref)) {
            match (status) {
                case Status.IN => throw Exception("Could not infer the type of " + "${ref.identifier.value}")
                case Status.VIS => return
            }
        }
        referenceStatus.add(ref, Status.IN)

        // Set effective type to parameters (= to declaration type)
        ref.paramRef.getOrThrow().iterator().enumerate().forEach(
            {
                entry =>
                    let (idx, paramRef) = entry
                    paramRef.effectiveType = funcDeclWithRef.params[idx].paramType.traverse(typeAssigner)
            }
        )

        // Declare function if it is not already declared.
        if (declToTypeManager.get(funcDeclWithRef).isNone()) {
            typeManager.addFunction(ref)
        }

        if (let Some(declType) <- funcDeclWithRef.declType) {
            declType.traverse(this)
        }
        if (let Some(funcBlock) <- funcDeclWithRef.block) {
            funcBlock.traverse(this)
        }
        nodePossibleTypes.add(funcDeclWithRef.id, HashSet([funcDeclWithRef.traverse(typeAssigner)]))

        referenceStatus.add(ref, Status.VIS)
        typeManager = precTypeManager
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): Unit {
        let ref: MainReference = mainDeclWithRef.mainRef
        // Set effective type to parameter (= to declaration type)
        if (let Some(param) <- mainDeclWithRef.param && let Some(paramRef) <- ref.paramRef) {
            paramRef.effectiveType = param.traverse(typeAssigner)
        }

        mainDeclWithRef.block.traverse(this)

        if (let Some(declType) <- mainDeclWithRef.declType) {
            declType.traverse(this)
        }
        nodePossibleTypes.add(mainDeclWithRef.id, HashSet([mainDeclWithRef.traverse(typeAssigner)]))
    }

    public override func visit(varReference: VariableReference): Unit {
        if (let Some(effectiveType) <- varReference.effectiveType) {
            nodePossibleTypes.add(varReference.id, HashSet([effectiveType]))
            return
        }
        let decl: Decl = refToDecl.get(varReference).getOrThrow()
        if (let Some(declType) <- decl.declType) {
            declType.traverse(this)
            nodePossibleTypes.add(varReference.id, HashSet(nodePossibleTypes[declType.id]))
            return
        }

        decl.traverse(this)
    }

    public override func visit(classReference: ClassReference): Unit {
        if (let Some(effective) <- classReference.effectiveType) {
            nodePossibleTypes.add(classReference.id, HashSet([effective]))
        } else {
            let tp: Type = typeManager.getType(classReference.identifier.value)
            classReference.effectiveType = tp
            nodePossibleTypes.add(classReference.id, HashSet([tp]))
        }
        perform CallableFieldBus("", classReference.identifier.value)
    }

    public override func visit(funcReference: FuncReference): Unit {
        if (let Some(effectiveType) <- funcReference.effectiveType) {
            nodePossibleTypes.add(funcReference.id, HashSet([effectiveType]))
        } else {
            let decl = refToDecl[funcReference]
            // If there is declaration type I assign it.
            if (let Some(declType) <- decl.declType) {
                let tp: Type = declType.traverse(typeAssigner)
                nodePossibleTypes.add(funcReference.id, HashSet([tp]))
                funcReference.effectiveType = tp
            } else { // Otherwise I have to visit the declaration that will assign the type.
                decl.traverse(this)
                nodePossibleTypes.add(funcReference.id, HashSet([funcReference.effectiveType.getOrThrow()]))
            }
        }
        perform CallableFieldBus(funcReference.identifier.value, None)
    }

    public override func visit(refExprWithRef: RefExprWithRef): Unit {
        refExprWithRef.ref.traverse(this)
        nodePossibleTypes.add(refExprWithRef.id, HashSet(nodePossibleTypes[refExprWithRef.ref.id]))
    }

    public override func visit(callExprWithRef: CallExprWithRef): Unit {
        let callableField: Box<?CallableFieldBus> = Box(None)
        try {
            callExprWithRef.callee.traverse(this)
        } handle (callableFieldBus: CallableFieldBus) {
            callableField.value = callableFieldBus
            resume with ()
        }

        let identifier = callableField.value.getOrThrow({
            => Exception("Left of call expression not callable")
        }).field
        let baseType = callableField.value.getOrThrow().baseType

        callExprWithRef.arguments.iterator().forEach({v => v.traverse(this)})
        let args: Array<Set<Type>> = Utils
            .fold(callExprWithRef.arguments.iterator().map({v => nodePossibleTypes[v.id]}), ArrayList())
            .toArray()

        // Check first for a function call.
        let funcGrouping: Map<Type, ?FuncReference> = HashMap()

        let inheritedTypeName: ?Type = match (baseType) {
            case Some(baseTypeName) => typeManager.getType(baseTypeName)
            case None => match (currentMembersContainer) {
                case Some(membersCont) => typeManager.getType(membersCont.typeReference.identifier.value)
                case None => None
            }
        }

        let collectSuperScopes: () -> Map<Type, ?FuncReference> = {
            =>
                let map: Map<Type, ?FuncReference> = HashMap()
                let signs = HashSet<String>()

                if (let Some(type_) <- inheritedTypeName) {
                    let ancestors = type_.ancestors

                    ancestors.iterator().forEach(
                        {
                            superType =>
                                if (identifier == "" && superType != type_) {
                                    // If we are calling a constructor function, we can not call a constructor 
                                    // of our superType
                                    return
                                }

                                if (let Some(members) <- typeEnvironment.getLocal(superType.name)) {
                                    let newSigns = ArrayList<String>()
                                    members
                                        .typeManager
                                        .getOrThrow()
                                        .findClosestSuperType(identifier, args, None)
                                        .iterator()
                                        .forEach(
                                            {
                                                entry =>
                                                    // We want to keep only the first type and unique signatures.
                                                    if (let Some(funcRef) <- entry[1]) {
                                                        let funcHash = Utils.funcHashConcat(funcRef)
                                                        if (!signs.contains(funcHash)) {
                                                            newSigns.add(funcHash)
                                                            map.addIfAbsent(entry[0], entry[1])
                                                        }
                                                        return
                                                    }
                                                    map.addIfAbsent(entry[0], entry[1])
                                            }
                                        )
                                    signs.add(all: newSigns)
                                }
                        }
                    )
                }

                map
        }

        try {
            match (baseType) {
                case Some(baseTypeName) => funcGrouping.add(all: collectSuperScopes())
                case None => funcGrouping.add(all: typeManager.allFunctionsGlobal(identifier, args, collectSuperScopes))
            }
        } handle (_: VisitorEffect<Unit>) {
            resume with this
        } handle (_: CallableFieldBus) {
            resume with ()
        }

        functionTypeGrouping.add(callExprWithRef.id, funcGrouping)
        nodePossibleTypes.add(callExprWithRef.id, HashSet(funcGrouping.keys()))
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): Unit {
        currentMembersContainer = typeEnvironment
            .getGlobal(classDeclWithRef.ref.identifier.value)
            .getOrThrow({=> Exception("Unexpected, class should've been declared")})
        typeAssigner.currentMembersContainer = currentMembersContainer

        classDeclWithRef.ref.effectiveType = typeManager.getType(classDeclWithRef.identifier.value)
        classDeclWithRef.body.traverse(this)

        currentMembersContainer = None
        typeAssigner.currentMembersContainer = currentMembersContainer
    }

    public override func visit(body: Body): Unit {
        let globalScope = typeManager
        typeManager = currentMembersContainer.getOrThrow().typeManager.getOrThrow()

        body.decls.iterator().forEach({decl => decl.traverse(this)})

        typeManager = globalScope
    }

    public override func visit(memberAccessWithRef: MemberAccessWithRef): Unit {
        try {
            memberAccessWithRef.baseExpr.traverse(this)
        } handle (_: CallableFieldBus) {
            resume with ()
        }

        let baseType: Type = memberAccessWithRef.baseExpr.traverse(typeAssigner)

        var baseMembers: MembersContainer = typeEnvironment
            .getGlobal(baseType.name)
            .getOrThrow({=> Exception("Base of member access is not found!")})

        let field: String = memberAccessWithRef.field.value
        let (tp, isCallable) = getMemberType(baseMembers, field)

        memberAccessWithRef.ref = baseMembers.typeReference

        if (isCallable) {
            perform CallableFieldBus(field, baseType.name)
        } else {
            nodePossibleTypes.add(memberAccessWithRef.id, HashSet([tp]))
        }
    }

    public override func visit(thisSuperReference: ThisSuperReference): Unit {
        let classReference: ClassReference = (currentMembersContainer
            .getOrThrow({
                => Exception("Cannot have ${thisSuperReference.keyword.value} outside of a class")
            })
            .typeReference as ClassReference)
            .getOrThrow({
                => Exception("Cannot have ${thisSuperReference.keyword.value} outside of a class")
            })

        thisSuperReference.classReference = classReference

        if (thisSuperReference.keyword.kind == TokenKind.THIS) {
            nodePossibleTypes.add(thisSuperReference.id, HashSet([classReference.effectiveType.getOrThrow()]))
            perform CallableFieldBus("", classReference.identifier.value)
        } else {
            nodePossibleTypes.add(thisSuperReference.id,
                HashSet([classReference.parent.getOrThrow({
                    => Exception("Cannot invoke super without super type")
                }).effectiveType.getOrThrow()]))
            perform CallableFieldBus("", classReference.parent.getOrThrow().identifier.value)
        }
    }

    public override func visit(interfaceDecl: InterfaceDeclWithRef) {
        currentMembersContainer = typeEnvironment
            .getGlobal(interfaceDecl.ref.identifier.value)
            .getOrThrow({=> Exception("Unexpected, class should've been declared")})
        typeAssigner.currentMembersContainer = currentMembersContainer

        interfaceDecl.ref.effectiveType = typeManager.getType(interfaceDecl.identifier.value)
        interfaceDecl.body.traverse(this)

        currentMembersContainer = None
        typeAssigner.currentMembersContainer = currentMembersContainer
    }

    /*
     * Goes up to the supertypes until it finds the member, returns if the field is callable and its
     * type.
     */
    private func getMemberType(baseClass: MembersContainer, field: String): (Type, Bool) {
        if (let Some((tp, isCallable)) <- baseClass.getMember(field)) {
            return (tp, isCallable)
        }
        throw Exception("${field} is not defined in ${baseClass.typeReference.identifier.value}")
    }

    private func beginScope(): Unit {
        typeManager = TypeManager(typeManager)
    }

    private func endScope(): Unit {
        typeManager = typeManager.enclosing.getOrThrow({=> Exception("Trying to close the global scope")})
    }
}
