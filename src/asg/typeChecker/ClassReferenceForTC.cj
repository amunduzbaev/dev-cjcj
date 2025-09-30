package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.asg.TypeManager

public class ClassReferenceForTC {
    private var variableEnvironment_: ?Environment<String, VariableReference> = None
    private var typeManager_: ?TypeManager = None
    private let classReference_: ClassReference

    public init(classReference: ClassReference) {
        classReference_ = classReference
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
        None
    }
}