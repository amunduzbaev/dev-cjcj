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
}