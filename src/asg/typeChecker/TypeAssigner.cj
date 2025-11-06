package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.asg.TypeManager
import cjcj.asg.Utils
import cjcj.scanner.Token
import std.convert.*
import std.collection.*

/*
 * Tries to assign a single type to every node by loooking at the node possible types given.
 */
public class TypeAssigner <: Visitor<Type> {
    private var expectedReturnType: ?Type = None
    public var currentMembersContainer: ?MembersContainer = None

    // Stack that is filled by function declarations, used for the return expressions.
    // If there can be return expressions the element will contain the expected type and the set of
    // all the returned types.
    private var functionStackInfo: ArrayStack<?(?Type, Set<Type>)> = ArrayStack()

    public TypeAssigner(
        private let nodePossibleTypes: Map<NodeId, Set<Type>>,
        private var typeEnvironment: Environment<String, MembersContainer>,
        private let typeManager: TypeManager,
        private let functionTypeGrouping: Map<NodeId, Map<Type, ?FuncReference>>
    ) {}

    public override func visit(binaryExpr: BinaryExpr): Type {
        let exp: ?Type = expectedReturnType
        functionTypeGrouping[binaryExpr.id] = matchReturnType(functionTypeGrouping[binaryExpr.id])

        var bestFunc: ?FuncReference = None
        if (let Some(expected) <- exp) {
            if (let Some(fun) <- functionTypeGrouping[binaryExpr.id].get(expected)) {
                bestFunc = fun
            } else if (let Some(fun) <- functionTypeGrouping[binaryExpr.id].get(Type.NOTHING)) {
                bestFunc = fun
            }
        } else {
            if (let Some(fun) <- typeManager.bestFunction(
                functionTypeGrouping[binaryExpr
                        .id]
                    .iterator()
                    .filter({v => v[1].isSome()})
                    .map({v => v[1].getOrThrow()})
                    .fold(
                        HashSet(),
                        {
                            acc, v =>
                            acc.add(v);
                            acc
                        }
                    )
            )) {
                bestFunc = fun
            }
        }

        let refTypes: Array<Type> = Utils.refToType(bestFunc.getOrThrow({
            => Exception("Could not find a function for ${binaryExpr.oper.value}")
        }).paramRef.getOrThrow())

        expectedReturnType = refTypes[0]
        binaryExpr.left.traverse(this)

        expectedReturnType = refTypes[1]
        binaryExpr.right.traverse(this)

        expectedReturnType = exp
        bestFunc.getOrThrow().traverse(this)
    }

    public override func visit(unaryExpr: UnaryExpr): Type {
        let exp: ?Type = expectedReturnType
        functionTypeGrouping[unaryExpr.id] = matchReturnType(functionTypeGrouping[unaryExpr.id])

        var bestFunc: ?FuncReference = None
        if (let Some(expected) <- exp) {
            if (let Some(fun) <- functionTypeGrouping[unaryExpr.id].get(expected)) {
                bestFunc = fun
            } else if (let Some(fun) <- functionTypeGrouping[unaryExpr.id].get(Type.NOTHING)) {
                bestFunc = fun
            }
        } else {
            if (let Some(fun) <- typeManager.bestFunction(
                functionTypeGrouping[unaryExpr
                        .id]
                    .iterator()
                    .filter({v => v[1].isSome()})
                    .map({v => v[1].getOrThrow()})
                    .fold(
                        HashSet(),
                        {
                            acc, v =>
                            acc.add(v);
                            acc
                        }
                    )
            )) {
                bestFunc = fun
            }
        }

        let refTypes: Array<Type> = Utils.refToType(bestFunc.getOrThrow({
            => Exception("Could not find a function for ${unaryExpr.oper.value}")
        }).paramRef.getOrThrow())

        expectedReturnType = refTypes[0]
        unaryExpr.right.traverse(this)

        expectedReturnType = exp
        bestFunc.getOrThrow().traverse(this)
    }

    public override func visit(parenExpr: ParenExpr): Type {
        matchReturnType(parenExpr.parenthesizedExpr.traverse(this))
    }

    private func checkIntValue(value: String, tp: Type): Unit {
        if (tp == typeManager.getType("Int64")) {
            Int64.parse(value)
        } else if (tp == typeManager.getType("Int32")) {
            Int32.parse(value)
        } else if (tp == typeManager.getType("Int16")) {
            Int16.parse(value)
        } else if (tp == typeManager.getType("Int8")) {
            Int8.parse(value)
        } else if (tp == typeManager.getType("IntNative")) {
            let val: Int64 = Int64.parse(value)
            if (val > Int64(IntNative.Max) || val < Int64(IntNative.Min)) {
                throw Exception("the number '${val}' exceeds the value range of type 'IntNative'")
            }
        } else if (tp == typeManager.getType("UInt64")) {
            UInt64.parse(value)
        } else if (tp == typeManager.getType("UInt32")) {
            UInt32.parse(value)
        } else if (tp == typeManager.getType("UInt16")) {
            UInt16.parse(value)
        } else if (tp == typeManager.getType("UInt8")) {
            UInt8.parse(value)
        } else if (tp == typeManager.getType("UIntNative")) {
            let val: UInt64 = UInt64.parse(value)
            if (val > UInt64(UIntNative.Max) || val < UInt64(UIntNative.Min)) {
                throw Exception("the number '${val}' exceeds the value range of type 'UIntNative'")
            }
        } else if (tp == typeManager.getType("Hashable") || tp == typeManager.getType("ToString") || tp ==
            typeManager.getType("Any")) {
            Int64.parse(value)
        } else {
            throw Exception("Type expected is not an integer")
        }
    }

    private func checkFloatValue(value: String, tp: Type): Unit {
        if (tp == typeManager.getType("Float64")) {
            Float64.parse(value)
        } else if (tp == typeManager.getType("Float32")) {
            Float32.parse(value)
        } else if (tp == typeManager.getType("Float16")) {
            Float16.parse(value)
        } else if (tp == typeManager.getType("Hashable") || tp == typeManager.getType("ToString") || tp ==
            typeManager.getType("Any")) {
            Float64.parse(value)
        } else {
            throw Exception("Type expected is not an integer")
        }
    }

    public override func visit(litConstExpr: LitConstExpr): Type {
        let tp: Type = match (litConstExpr.literal.kind) {
            // TODO: Change this, compiler can do implicit cast.
            case TokenKind.INTEGER_LITERAL =>
                if (let Some(expected) <- expectedReturnType) {
                    if (nodePossibleTypes.get(litConstExpr.id).getOrThrow().contains(expected)) {
                        checkIntValue(litConstExpr.literal.value, expected)
                        return expected
                    }
                    throw Exception("Expected ${expected.name} found interger literal")
                } else {
                    typeManager.getType("Int64")
                }
            case TokenKind.FLOAT_LITERAL =>
                if (let Some(expected) <- expectedReturnType) {
                    if (nodePossibleTypes.get(litConstExpr.id).getOrThrow().contains(expected)) {
                        checkFloatValue(litConstExpr.literal.value, expected)
                        return expected
                    }
                    throw Exception("Expected ${expected.name} found float literal")
                } else {
                    typeManager.getType("Float64")
                }
            case TokenKind.BOOL_LITERAL => typeManager.getType("Bool")
            case TokenKind.STRING_LITERAL => typeManager.getType("String")
            case TokenKind.UNIT_LITERAL => Type.UNIT
            // TODO: Add all other literals.
            case _ => Type.DUMMY
        }
        matchReturnType(tp)
    }

    public override func visit(assignExpr: AssignExpr): Type {
        let left: Type = assignExpr.left.traverse(this)
        let exp: ?Type = expectedReturnType

        expectedReturnType = left

        let right: Type = assignExpr.right.traverse(this)
        if (!left.isParent(right)) {
            throw Exception("Cannot assign ${right.name} to ${left.name}")
        }
        expectedReturnType = exp
        matchReturnType(Type.UNIT)
    }

    public override func visit(block: Block): Type {
        let blockExpectedReturn: ?Type = expectedReturnType
        expectedReturnType = None

        let lastId = block.nodes.last.getOrDefault({=> Expr()}).id
        let returnType = block.nodes.iterator().map(
            {
                n =>
                    if (n.id == lastId) {
                        expectedReturnType = blockExpectedReturn
                    }
                    n.traverse(this)
            }
        ).last().getOrDefault({=> Type.UNIT})

        expectedReturnType = blockExpectedReturn
        matchReturnType(returnType)
    }

    public override func visit(ifExpr: IfExpr): Type {
        let ifExprExpectedReturn: ?Type = expectedReturnType

        expectedReturnType = typeManager.getType("Bool")
        ifExpr.condition.traverse(this)

        expectedReturnType = ifExprExpectedReturn
        let ifType: Type = ifExpr.ifBlock.traverse(this)
        let elseType: Type = ifExpr.elseBranch.traverse(this)

        if (let Some(expectedReturn) <- ifExprExpectedReturn) {
            return expectedReturn
        }
        // If I don't have an expected return type I need to take the smallest common supertype.
        typeManager.smallestCommonSupertype(ifType, elseType)
    }

    public override func visit(whileExpr: WhileExpr): Type {
        let whileExpectedReturn: ?Type = expectedReturnType

        expectedReturnType = typeManager.getType("Bool")
        whileExpr.condition.traverse(this)

        expectedReturnType = None
        whileExpr.block.traverse(this)

        expectedReturnType = whileExpectedReturn
        matchReturnType(Type.UNIT)
    }

    public override func visit(returnExpr: ReturnExpr): Type {
        let exp: ?Type = expectedReturnType
        let (expectedReturn, allReturnTypes): (?Type, Set<Type>) = functionStackInfo
            .peek()
            .getOrThrow({=> Exception("Cannot have return expression outside of a function")})
            .getOrThrow({=> Exception("Cannot have return expression inside an init function")})

        if (let Some(expr) <- returnExpr.expr) {
            expectedReturnType = expectedReturn
            allReturnTypes.add(expr.traverse(this))
        } else {
            allReturnTypes.add(Type.UNIT)
        }
        expectedReturnType = exp
        Type.NOTHING
    }

    public override func visit(funcParam: FuncParam): Type {
        matchReturnType(funcParam.paramType.traverse(this))
    }

    public override func visit(argument: Argument): Type {
        matchReturnType(argument.expr.traverse(this))
    }

    public override func visit(primitiveType: PrimitiveType): Type {
        matchReturnType(typeManager.getType(primitiveType.typeName.value))
    }

    public override func visit(refType: RefType): Type {
        matchReturnType(typeManager.getType(refType.typeName.value))
    }

    public override func visit(varDeclWithRef: VarDeclWithRef): Type {
        let ref: Reference = varDeclWithRef.ref

        let varDeclExpectedReturn: ?Type = expectedReturnType

        var targetType: ?Type = if (let Some(declType) <- varDeclWithRef.declType) {
            declType.traverse(this)
        } else {
            None
        }

        expectedReturnType = targetType
        let initType: ?Type = if (let Some(initzer) <- varDeclWithRef.initializer) {
            initzer.traverse(this)
        } else {
            None
        }

        ref.effectiveType = targetType.getOrDefault({
            => initType.getOrThrow({=> Exception("No declaration type and not initializer found")})
        })

        expectedReturnType = varDeclExpectedReturn
        matchReturnType(Type.UNIT)
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): Type {
        let ref: FuncReference = funcDeclWithRef.funcRef

        let funcDeclExpectedReturn: ?Type = expectedReturnType

        if (funcDeclWithRef.keyword.kind == TokenKind.INIT) {
            let classRef = (currentMembersContainer
                .getOrThrow({
                    => Exception("Cannot have init function outside of a class")
                })
                .typeReference as ClassReference)
                .getOrThrow({=> Exception("Cannot have init function outside of a class")})

            ref.effectiveType = typeManager.getType(classRef.identifier.value)

            // Inits cannot have return expressions.
            functionStackInfo.add(None)
            if (let Some(funcBlock) <- funcDeclWithRef.block) {
                funcBlock.traverse(this)
            }
        } else {
            let targetType: ?Type = if (let Some(declType) <- funcDeclWithRef.declType) {
                declType.traverse(this)
            } else {
                None
            }
            let allReturns: Set<Type> = HashSet()
            functionStackInfo.add((targetType, allReturns))

            expectedReturnType = targetType
            let blockType: Type = match (funcDeclWithRef.block) {
                case Some(funcBlock) => funcBlock.traverse(this)
                case _ => targetType.getOrThrow()
            }

            if (let Some(targetType) <- targetType) {
                ref.effectiveType = targetType
            } else {
                let returnType: Type = if (allReturns.size == 1) {
                    allReturns.iterator().first().getOrThrow()
                } else {
                    allReturns
                        .iterator()
                        .reduce({a, b => typeManager.smallestCommonSupertype(a, b)})
                        .getOrDefault({=> Type.NOTHING})
                }
                ref.effectiveType = typeManager.smallestCommonSupertype(returnType, blockType)
            }
        }

        expectedReturnType = funcDeclExpectedReturn
        matchReturnType(Type.UNIT)
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): Type {
        let ref: MainReference = mainDeclWithRef.mainRef

        let mainDeclExpectedReturn: ?Type = expectedReturnType

        let targetType: ?Type = if (let Some(declType) <- mainDeclWithRef.declType) {
            declType.traverse(this)
        } else {
            None
        }

        let allReturns: Set<Type> = HashSet()
        functionStackInfo.add((targetType, allReturns))

        expectedReturnType = targetType
        let blockType: Type = mainDeclWithRef.block.traverse(this)

        if (let Some(targetType) <- targetType) {
            ref.effectiveType = targetType
        } else {
            ref.effectiveType = typeManager.smallestCommonSupertype(
                allReturns
                    .iterator()
                    .reduce({a, b => typeManager.smallestCommonSupertype(a, b)})
                    .getOrDefault({=> Type.NOTHING}), blockType)
        }

        expectedReturnType = mainDeclExpectedReturn
        matchReturnType(Type.UNIT)
    }

    public override func visit(varReference: VariableReference): Type {
        if (let Some(effectiveType) <- varReference.effectiveType) {
            return effectiveType
        }

        // If I haven't seen it before it must have only one possible type
        if (nodePossibleTypes[varReference.id].size != 1) {
            throw Exception("Impossible to infer the value of var reference " + "${varReference.identifier.value}")
        }
        let tp: Type = nodePossibleTypes[varReference.id].iterator().first().getOrThrow()
        varReference.effectiveType = tp
        matchReturnType(tp)
    }

    public override func visit(classReference: ClassReference): Type {
        if (let Some(effectiveType) <- classReference.effectiveType) {
            return effectiveType
        }
        // If I haven't seen it before it must have only one possible type
        if (nodePossibleTypes[classReference.id].size != 1) {
            throw Exception("Impossible to infer the value of class reference ${classReference.identifier.value}")
        }
        let tp: Type = nodePossibleTypes[classReference.id].iterator().first().getOrThrow()
        classReference.effectiveType = tp
        matchReturnType(tp)
    }

    public override func visit(funcReference: FuncReference): Type {
        // This is not the real func reference, I cannot trust it.
        if (let Some(effectiveType) <- funcReference.effectiveType) {
            return effectiveType
        }
        Type.DUMMY
    }

    public override func visit(refExprWithRef: RefExprWithRef): Type {
        matchReturnType(refExprWithRef.ref.traverse(this))
    }

    public override func visit(callExprWithRef: CallExprWithRef): Type {
        var bestFunc: ?FuncReference = None
        let exp: ?Type = expectedReturnType

        if (let Some(expected) <- expectedReturnType) {
            if (let Some(fun) <- functionTypeGrouping[callExprWithRef.id].get(expected)) {
                bestFunc = fun
            } else if (let Some(fun) <- functionTypeGrouping[callExprWithRef.id].get(Type.NOTHING)) {
                bestFunc = fun
            }
        } else {
            if (let Some(fun) <- typeManager.bestFunction(
                functionTypeGrouping[callExprWithRef
                        .id]
                    .iterator()
                    .filter({v => v[1].isSome()})
                    .map({v => v[1].getOrThrow()})
                    .fold(
                        HashSet(),
                        {
                            acc, v =>
                            acc.add(v);
                            acc
                        }
                    )
            )) {
                bestFunc = fun
            }
        }

        let paramRef: ArrayList<VariableReference> = bestFunc.getOrThrow({
            => Exception("Could not find a function to call")
        }).paramRef.getOrThrow()
        let refTypes: Array<Type> = Utils.refToType(paramRef)

        for (id in 0..refTypes.size) {
            let tp = refTypes[id]
            expectedReturnType = tp
            callExprWithRef.arguments[id].traverse(this)

            expectedReturnType = tp
            paramRef[id].traverse(this)
        }
        expectedReturnType = exp

        // Set the reference to the correct one.
        callExprWithRef.ref = bestFunc.getOrThrow()
        bestFunc.getOrThrow().effectiveType.getOrThrow()
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): Type {
        classDeclWithRef.body.traverse(this)
        matchReturnType(Type.UNIT)
    }

    public override func visit(body: Body): Type {
        body.decls.iterator().forEach({decl => decl.traverse(this)})
        matchReturnType(Type.DUMMY)
    }

    public override func visit(memberAccessWithRef: MemberAccessWithRef): Type {
        let expected: ?Type = expectedReturnType

        // Call baseClass without exected return type because it is independent from outside.
        expectedReturnType = None
        let baseClass: MembersContainer = typeEnvironment
            .getGlobal(memberAccessWithRef.baseExpr.traverse(this).name)
            .getOrThrow({=> Exception("Base of member access is not a class!")})

        expectedReturnType = expected
        let (tp, _) = baseClass.getMember(memberAccessWithRef.field.value).getOrThrow()
        if (let Some(expected) <- expectedReturnType) {
            if (!expected.isParent(tp)) {
                throw Exception("Expected ${expected.name} found ${tp.name}")
            }
        }

        // Set the right reference to the member access.
        memberAccessWithRef.ref = baseClass.typeReference
        tp
    }

    public override func visit(thisSuperReference: ThisSuperReference): Type {
        let classReference: ClassReference = thisSuperReference.classReference.getOrThrow()
        if (thisSuperReference.keyword.kind == TokenKind.THIS) {
            return matchReturnType(classReference.effectiveType.getOrThrow())
        }
        matchReturnType(classReference.parent.getOrThrow({
            => Exception("Cannot invoke super without super type")
        }).effectiveType.getOrThrow())
    }

    /*
     * Filter the functions by return type.
     */
    private func matchReturnType(funcs: Map<Type, ?FuncReference>): Map<Type, ?FuncReference> {
        if (let Some(expected) <- expectedReturnType) {
            return funcs.iterator().map(
                {
                    entry: (Type, ?FuncReference) =>
                        let (tp, opf) = entry
                        if (let Some(f) <- opf && !expected.isParent(f.traverse(this))) {
                            return (tp, Option<FuncReference>.None)
                        }
                        return entry
                }
            ).fold(
                HashMap(),
                {
                    acc, v =>
                    acc.add(v[0], v[1]);
                    acc
                }
            )
        }
        funcs
    }

    /*
     * Throws an exception if the given type is not a subtype of the expected return type.
     */
    private func matchReturnType(tp: Type): Type {
        if (let Some(expected) <- expectedReturnType && !expected.isParent(tp)) {
            throw Exception("Found ${tp.name}, expected ${expected.name}")
        }
        tp
    }
}
