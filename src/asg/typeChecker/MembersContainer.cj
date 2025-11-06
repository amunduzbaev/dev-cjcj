package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.asg.TypeManager
import stdx.effect.Command

public class CallableFieldBus <: Command<Unit> {
    public CallableFieldBus(public let field: String, public let baseType: ?String) {}
}

public class MembersContainer {
    private var variableEnvironment_: ?Environment<String, VariableReference> = None
    private var typeManager_: ?TypeManager = None
    private let typeReference_: Reference
    private let superClass_: ?MembersContainer

    public init(typeReference: Reference, superClass: ?MembersContainer) {
        typeReference_ = typeReference
        superClass_ = superClass
    }
    public init(typeReference: Reference) {
        this(typeReference, None)
    }

    public mut prop variableEnvironment: ?Environment<String, VariableReference> {
        get() {
            variableEnvironment_
        }
        set(v) {
            variableEnvironment_ = v
        }
    }

    public mut prop typeManager: ?TypeManager {
        get() {
            typeManager_
        }
        set(v) {
            typeManager_ = v
        }
    }

    public prop typeReference: Reference {
        get() {
            typeReference_
        }
    }

    public func getMember(field: String): ?(Type, Bool) {
        // Try to find a variable.
        if (let Some(varRef) <- variableEnvironment.getOrThrow().getLocal(field)) {
            return (varRef.effectiveType.getOrThrow(), false)
        }

        // Try to find a function.
        if (typeManager.getOrThrow().funcExists(field)) {
            // I cannot know the return type of the function so I just tell the callExpr who to call
            // and from which class.
            return (typeManager.getOrThrow().getType(typeReference.identifier.value), true)
        }

        match (superClass) {
            case Some(superClass) => superClass.getMember(field)
            case _ => None
        }
    }

    public func getVariableMembersReference(field: String): ?VariableReference {
        variableEnvironment.getOrThrow().getGlobal(field)
    }

    public func isFunctionMember(ref: FuncReference): Bool {
        if (typeManager.getOrThrow().exactFuncExists(ref)) {
            return true
        }

        match (superClass) {
            case Some(superClass) => superClass.isFunctionMember(ref)
            case _ => false
        }
    }

    public prop superClass: ?MembersContainer {
        get() {
            superClass_
        }
    }
}
