package cjcj.asg.declarators

import cjcj.visitor.*
import cjcj.parser.NodeIdManager

public class GlobalDeclarator <: BodyDeclarator {
    private var classEnvironment: Environment<String, ClassReference>
    
    public init(
        funcEnvironment: Environment<String, FuncReference>,
        variableEnvironment: Environment<String, VariableReference>,
        classEnvironment: Environment<String, ClassReference>
    ) {
        super(funcEnvironment, variableEnvironment)
        this.classEnvironment = classEnvironment
    }

    protected override func canDeclare(key: String): Bool {
        super.canDeclare(key) && classEnvironment.getLocal(key).isNone()
    }

    public override func visit(classDecl: ClassDecl): ?Reference {
        let ref = ClassReference(NodeIdManager.nextId(), classDecl.identifier)
        if (canDeclare(classDecl.identifier.value)) {
            classEnvironment.declare(classDecl.identifier.value, ref)
        }
        ref
    }

    public override func visit(_: VarDecl): ?Reference {
        None
    }
}