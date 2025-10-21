package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.asg.TypeManager

public class ClassReferenceForTC {
    private var variableEnvironment_: ?Environment<String, VariableReference> = None
    private var typeManager_: ?TypeManager = None
    private let classReference_: ClassReference
    private let superClass: ?ClassReferenceForTC

    public init(classReference: ClassReference, superClass: ?ClassReferenceForTC) {
        classReference_ = classReference
        this.superClass = superClass
    }
    public init(classReference: ClassReference) {
        this(classReference, None)
    }

    public mut prop variableEnvironment: ?Environment<String, VariableReference> {
        get() { variableEnvironment_ }
        set(v) { variableEnvironment_ = v }
    }

    public mut prop typeManager: ?TypeManager {
        get() { typeManager_ }
        set(v) { typeManager_ = v }
    }

    public prop classReference: ClassReference {
        get() { classReference_ }
    }

    public func getMember(field: String): ?(Type, Bool) {

        // Try to find a variable.
        if (let Some(varRef) <- variableEnvironment.getOrThrow().getGlobal(field)) {
            return (varRef.effectiveType.getOrThrow(), false)
        }

        // Try to find a function.
        if (typeManager.getOrThrow().funcExists(field)) {
            // I cannot know the return type of the function so I just tell the callExpr who to call
            // and from which class.
            return (typeManager.getOrThrow().getType(classReference.identifier.value), true)
        }

        match (superClass) {
            case Some(superClass) => superClass.getMember(field)
            case _ => None
        }
    }

    public func getMembersReference(field: String): ?VariableReference {
        variableEnvironment.getOrThrow().getGlobal(field)
    }
}

public class MembersContainer {
    private var variableEnvironment_: ?Environment<String, VariableReference> = None
    private var typeManager_: ?TypeManager = None
    private let typeReference_: Reference
    private let superClass: ?MembersContainer

    public init(typeReference: Reference, superClass: ?MembersContainer) {
        typeReference_ = typeReference
        this.superClass = superClass
    }
    public init(typeReference: Reference) {
        this(typeReference, None)
    }

    public mut prop variableEnvironment: ?Environment<String, VariableReference> {
        get() { variableEnvironment_ }
        set(v) { variableEnvironment_ = v }
    }

    public mut prop typeManager: ?TypeManager {
        get() { typeManager_ }
        set(v) { typeManager_ = v }
    }

    public prop typeReference: Reference {
        get() { typeReference_ }
    }

    public func getMember(field: String): ?(Type, Bool) {
        // Try to find a variable.
        if (let Some(varRef) <- variableEnvironment.getOrThrow().getGlobal(field)) {
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

    public func getMembersReference(field: String): ?VariableReference {
        variableEnvironment.getOrThrow().getGlobal(field)
    }
}
