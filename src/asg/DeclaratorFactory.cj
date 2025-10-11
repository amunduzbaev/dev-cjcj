package cjcj.asg

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.parser.NodeIdManager

import std.collection.ArrayList
import std.collection.Map
import std.collection.Set

/*
* Declarator for the ASG, allows to handle all declarations with references.
*/
private class ReferenceDeclarator <: Declarator {
    public ReferenceDeclarator(
        private let visitVar!: (VarDeclWithRef) -> Unit = { _ => () },
        private let visitFunc!: (FuncDeclWithRef) -> Unit = { _ => () },
        private let visitClass!: (ClassDeclWithRef) -> Unit = { _ => () },
        private let visitMain!: (MainDeclWithRef) -> Unit = { _ => () }
    ) {
        super()
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): Unit {
        visitFunc(funcDeclWithRef)
    }

    public override func visit(varDeclWithRef: VarDeclWithRef): Unit {
        visitVar(varDeclWithRef)
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): Unit {
        visitClass(classDeclWithRef)
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): Unit {
        visitMain(mainDeclWithRef)
    }
}

/*
* Factory for declarators, can retrieve declarators with different behaviors.
*/
public abstract class DeclaratorFactory {
    /*
    * Declarator for the class, struct... bodies in the ASG, declares all functions and variables.
    * Functions signatures are checked based on the name and the type of the parameters.
    * Every reference will be linked with its declaration.
    */
    public static func bodyAsgDeclarator(
        variableEnvironment: Environment<String, VariableReference>,
        typeManager: TypeManager,
        refToDecl: Map<Reference, Decl>,
        declToRef: Map<Decl, Reference>,
        declToTypeManager: Map<Decl, TypeManager>,
        funcParamToRef: (FuncParam) -> VariableReference
    ): Declarator {
        let canDeclare: (String) -> Bool = canDeclare([
            { k => variableEnvironment.getLocal(k).isNone() }
        ])
        Declarator(
            visitFunc: functionAsgDeclaration(typeManager, canDeclare, refToDecl, declToRef,
                declToTypeManager, funcParamToRef),
            visitVar: variableAsgDeclaration(variableEnvironment, canDeclare, refToDecl, declToRef)
        )
    }

    /*
    * Declarator for the global scope in the ASG, declares all function, classes and variables.
    * Every reference will be linked with its declaration.
    */
    public static func globalAsgDeclarator(
        typeManager: TypeManager,
        variableEnvironment: Environment<String, VariableReference>,
        refToDecl: Map<Reference, Decl>,
        declToRef: Map<Decl, Reference>,
        declToTypeManager: Map<Decl, TypeManager>,
        funcParamToRef: (FuncParam) -> VariableReference,
        userDefinedClass: Set<String>
    ): Declarator {
        let canDeclare: (String) -> Bool = canDeclare([
            { k => !userDefinedClass.contains(k) },
            { k => variableEnvironment.getLocal(k).isNone() }
        ])
        Declarator(
            visitFunc: functionAsgDeclaration(typeManager, canDeclare, refToDecl, declToRef,
                declToTypeManager, funcParamToRef),
            visitVar: variableAsgDeclaration(variableEnvironment, canDeclare, refToDecl, declToRef)
        )
    }

    private static func variableAsgDeclaration(
        environment: Environment<String, VariableReference>,
        canDeclare: (String) -> Bool,
        refToDecl: Map<Reference, Decl>,
        declToRef: Map<Decl, Reference>
    ): (VarDecl) -> Unit {
        { varDecl: VarDecl =>
            if (canDeclare(varDecl.identifier.value)) {
                let ref: VariableReference = VariableReference(NodeIdManager.nextId(), 
                    varDecl.identifier, varDecl.keyword)
                refToDecl.add(ref, varDecl)
                declToRef.add(varDecl, ref)
                environment.declare(varDecl.identifier.value, ref)
                return
            }
            throw declareError(varDecl.identifier.value)
        }
    }

    private static func functionAsgDeclaration(
        typeManager: TypeManager,
        canDeclare: (String) -> Bool,
        refToDecl: Map<Reference, Decl>,
        declToRef: Map<Decl, Reference>,
        declToTypeManager: Map<Decl, TypeManager>,
        funcParamToRef: (FuncParam) -> (VariableReference)
    ): (FuncDecl) -> Unit {
        { funcDecl: FuncDecl =>
            let ref: FuncReference = FuncReference(NodeIdManager.nextId(), funcDecl.identifier)
            let funcName: String = ref.identifier.value
            let paramRef: ArrayList<VariableReference> = ArrayList()
            ref.paramRef = Utils.funcParamToParamRef(funcDecl.params, typeManager, funcParamToRef)
            let params: Array<Type> = Utils.refToType(paramRef)
            if (canDeclare(funcName)) {
                refToDecl.add(ref, funcDecl)
                declToRef.add(funcDecl, ref)
                declToTypeManager.add(funcDecl, typeManager)
                typeManager.addFunction(ref)
                return
            }
            throw declareError(
                funcName +
                params.iterator().map({ p => p.name })
                    .reduce({ a, b => a + b}).getOrDefault({ => ""})
            )
        }
    }

    private static func canDeclare(predicates: Array<(String) -> Bool>): (String) -> Bool {
        { key => predicates.iterator().all({ p => p(key) }) }
    }

    private static func declareError(name: String): Exception {
        Exception("Cannot declare ${name}")
    }
}