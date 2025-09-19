package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.TokenKind
import cjcj.scanner.Token
import cjcj.asg.ScopeType
import cjcj.asg.TypeManager
import cjcj.asg.Declarator
import cjcj.asg.DeclaratorFactory

import std.collection.*

/*
* Visitor that will visit the global scope and body declarations and will assign the effective type
* to the references if the declarations have a declaration type.
*/
public class GlobalBodyTypeAssigner <: Visitor<Type> {
    private var currentClass: ?ClassReferenceForTC = None

    /*
    * It expects to have every class declared and a typeManager to query and insert new functions
    * that are not declared in the global scope.
    */
    public GlobalBodyTypeAssigner(
        private var classEnvironment: Environment<String, ClassReferenceForTC>,
        private let typeManager: TypeManager,
        private let funcToDecl: Map<Reference, FuncDeclWithRef>
    ) { }

    public override func visit(program: Program): Type {
        program.decls.iterator().forEach({ d => d.traverse(this) })
        Type.DUMMY
    }

    public override func visit(funcParam: FuncParam): Type {
        funcParam.paramType.traverse(this)
    }

    public override func visit(primitiveType: PrimitiveType): Type {
        typeManager.getType(primitiveType.typeName.value)
    }

    public override func visit(refType: RefType): Type {
        typeManager.getType(refType.typeName.value)
    }

    public override func visit(varDeclWithRef: VarDeclWithRef): Type {
        let ref: Reference = varDeclWithRef.ref
        if (let Some(t) <- varDeclWithRef.declType) {
            ref.effectiveType = t.traverse(this)
        }
        typeManager.getType("Unit")
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): Type {
        let ref: FuncReference = funcDeclWithRef.funcRef
        funcToDecl.add(ref, funcDeclWithRef)

        let params = funcDeclWithRef.params
        // Set effective type to parameters (= to declaration type)
        ref.paramRef.getOrThrow().iterator().enumerate()
            .forEach({ v => v[1].effectiveType = params[v[0]].paramType.traverse(this) })

        if (let Some(decl) <- funcDeclWithRef.declType) {
            ref.effectiveType = decl.traverse(this)
            return typeManager.getType("Unit")
        }
        if (funcDeclWithRef.keyword.kind == TokenKind.INIT) {
            ref.effectiveType = typeManager.getType(currentClass.getOrThrow()
                .classReference.identifier.value)
            return typeManager.getType("Unit")
        }
        typeManager.getType("Unit")
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): Type {
        let ref: MainReference = mainDeclWithRef.mainRef

        // Set effective type to parameter (= to declaration type)
        if (let Some(paramRef) <- ref.paramRef) {
            paramRef.effectiveType = mainDeclWithRef.param.getOrThrow().traverse(this)
        }

        if (let Some(decl) <- mainDeclWithRef.declType) {
            ref.effectiveType = decl.traverse(this)
            return typeManager.getType("Unit")
        }
        typeManager.getType("Unit")
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): Type {
        currentClass = classEnvironment.getGlobal(classDeclWithRef.identifier.value)
        // TODO: Update this when we'll have interfaces.
        // If no supertypes the supertype will be Object.
        if (classDeclWithRef.superTypes.isEmpty()) {
            currentClass.getOrThrow().classReference.parent =
                classEnvironment.getGlobal("Object").getOrThrow().classReference
        } else if (
            classDeclWithRef.superTypes.size == 1 &&
            let Some(superClass) <- classDeclWithRef.superTypes.get(0)
        ) {
            // Update the parent in the reference.
            currentClass.getOrThrow().classReference.parent =
                classEnvironment.getGlobal(superClass.typeName.value).getOrThrow().classReference
        } else {
            throw Exception("Invalid number of superclasses, it can be max 1.")
        }
        classDeclWithRef.ref.effectiveType = typeManager.getType(classDeclWithRef.identifier.value)

        classDeclWithRef.body.traverse(this)
        currentClass = None
        typeManager.getType("Unit")
    }

    public override func visit(body: Body): Type {
        typeManager.beginScope()

        let variableEnvironment: Environment<String, VariableReference> = Environment()
        let bodyDeclarator: Declarator =
            DeclaratorFactory.bodyAsgDeclarator(variableEnvironment, typeManager)
        body.decls.iterator().forEach({ decl => decl.traverse(bodyDeclarator) })

        currentClass.getOrThrow().typeManager = TypeManager(typeManager)
        currentClass.getOrThrow().variableEnvironment = variableEnvironment

        body.decls.iterator().forEach({ decl => decl.traverse(this) })

        typeManager.endScope()

        currentClass.getOrThrow().typeManager.getOrThrow().deleteHistory()
        currentClass.getOrThrow().variableEnvironment.getOrThrow().enclosing = None

        Type.DUMMY
    }
}
