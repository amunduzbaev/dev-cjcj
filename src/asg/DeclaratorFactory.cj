package cjcj.asg

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.parser.NodeIdManager

import std.collection.ArrayList
import std.collection.Map

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
    * Declarator for the class, struct... bodies in the AST, declares all function and variables. 
    */
    public static func bodyAstDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        funcNameEnvironment: Environment<String, FuncReference>,
        variableEnvironment: Environment<String, VariableReference>
    ): Declarator {
        let canDeclare: (String) -> Bool = canDeclare([
            { k => variableEnvironment.getLocal(k).isNone() },
            { k => funcNameEnvironment.getLocal(k).isNone() }
        ])
        Declarator(
            visitFunc: functionAstDeclaration(funcEnvironment, funcNameEnvironment, canDeclare),
            visitVar: variableAstDeclaration(variableEnvironment, canDeclare)
        )
    }

    /*
    * Declarator for the global scope in the AST, declares all function and classes.
    */
    public static func globalAstDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        funcNameEnvironment: Environment<String, FuncReference>,
        classEnvironment: Environment<String, ClassReference>
    ): Declarator {
        let canDeclare: (String) -> Bool = canDeclare([
            { k => classEnvironment.getLocal(k).isNone() },
            { k => funcNameEnvironment.getLocal(k).isNone() }
        ])
        Declarator(
            visitFunc: functionAstDeclaration(funcEnvironment, funcNameEnvironment, canDeclare),
            visitClass: classAstDeclaration(classEnvironment, canDeclare)
        )
    }

    /*
    * Declarator for the class, struct... bodies in the ASG, declares all functions and variables.
    * Functions signatures are checked based on the name and the type of the parameters.
    * Every reference will be linked with its declaration.
    */
    public static func bodyAsgDeclarator(
        variableEnvironment: Environment<String, VariableReference>,
        typeManager: TypeManager,
        refToDecl: Map<Reference, Decl>,
        declToTypeManager: Map<Decl, TypeManager>
    ): Declarator {
        let canDeclare: (String) -> Bool = canDeclare([
            { k => variableEnvironment.getLocal(k).isNone() }
        ])
        ReferenceDeclarator(
            visitFunc: functionAsgDeclaration(typeManager, canDeclare, refToDecl, declToTypeManager),
            visitVar: variableAsgDeclaration(variableEnvironment, canDeclare, refToDecl)
        )
    }

    /*
    * Declarator for the global scope in the ASG, declares all function, classes and variables.
    * Functions signatures are checked based on the name and the type of the parameters.
    * Every reference will be linked with its declaration.
    */
    public static func globalAsgDeclarator(
        classEnvironment: Environment<String, ClassReference>,
        typeManager: TypeManager,
        refToDecl: Map<Reference, Decl>,
        declToTypeManager: Map<Decl, TypeManager>
    ): Declarator {
        let canDeclare: (String) -> Bool = canDeclare([
            { k => classEnvironment.getLocal(k).isNone() }
        ])
        ReferenceDeclarator(
            visitFunc: functionAsgDeclaration(typeManager, canDeclare, refToDecl, declToTypeManager),
            visitClass: classAsgDeclaration(classEnvironment, canDeclare),
            visitVar: variableAsgDeclaration(Environment(), canDeclare, refToDecl)
        )
    }

    private static func variableAstDeclaration(
        environment: Environment<String, VariableReference>,
        canDeclare: (String) -> Bool
    ): (VarDecl) -> Unit {
        { varDecl: VarDecl =>
            let ref: VariableReference = VariableReference(NodeIdManager.nextId(), 
                varDecl.identifier, varDecl.keyword)
            if (canDeclare(varDecl.identifier.value)) {
                environment.declare(varDecl.identifier.value, ref)
                return
            }
            throw declareError(varDecl.identifier.value)
        }
    }

    private static func variableAsgDeclaration(
        environment: Environment<String, VariableReference>,
        canDeclare: (String) -> Bool,
        refToDecl: Map<Reference, Decl>
    ): (VarDeclWithRef) -> Unit {
        { varDeclWithRef: VarDeclWithRef =>
            let ref: VariableReference = varDeclWithRef.ref
            if (canDeclare(varDeclWithRef.identifier.value)) {
                refToDecl.add(ref, varDeclWithRef)
                environment.declare(varDeclWithRef.identifier.value, ref)
                return
            }
            throw declareError(varDeclWithRef.identifier.value)
        }
    }

    private static func functionAstDeclaration(
        environment: Environment<String, FuncReference>,
        funcNameEnvironment: Environment<String, FuncReference>,
        canDeclare: (String) -> Bool
    ): (FuncDecl) -> Unit {
        { funcDecl: FuncDecl =>
            let ref: FuncReference = FuncReference(NodeIdManager.nextId(), funcDecl.identifier)
            let funcName: String = funcDecl.identifier.value
            let funcHashConcat: String = TypeManager.funcHashConcat(
                funcName, Utils.fold(
                    funcDecl.params.iterator().map({ p => p.paramType.typeName.value }),
                    ArrayList()
                ).toArray()
            )
            if (canDeclare(funcName)) {
                funcNameEnvironment.declare(funcName, ref)
                environment.declare(funcHashConcat, ref)
                return
            } else if (funcNameEnvironment.getLocal(funcName).isSome()) {
                environment.declare(funcHashConcat, ref)
                return
            }
            throw declareError(funcName)
        }
    }

    private static func functionAsgDeclaration(
        typeManager: TypeManager,
        canDeclare: (String) -> Bool,
        refToDecl: Map<Reference, Decl>,
        declToTypeManager: Map<Decl, TypeManager>
    ): (FuncDeclWithRef) -> Unit {
        { funcDeclWithRef: FuncDeclWithRef =>
            let ref: FuncReference = funcDeclWithRef.funcRef
            let funcName: String = ref.identifier.value
            let paramRef: ArrayList<VariableReference> = ref.paramRef.getOrThrow()
            Utils.funcParamToParamRef(
                funcDeclWithRef.params, ref.paramRef.getOrThrow(), typeManager
            )
            let params: Array<Type> = Utils.refToType(paramRef)
            if (canDeclare(funcName)) {
                refToDecl.add(ref, funcDeclWithRef)
                declToTypeManager.add(funcDeclWithRef, typeManager)
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

    private static func classAstDeclaration(
        environment: Environment<String, ClassReference>,
        canDeclare: (String) -> Bool
    ): (ClassDecl) -> Unit {
        { classDecl: ClassDecl =>
            // TODO: At the moment every class is considered open.
            let ref: ClassReference = ClassReference(NodeIdManager.nextId(), classDecl.identifier, true)
            if (canDeclare(classDecl.identifier.value)) {
                environment.declare(classDecl.identifier.value, ref)
                return
            }
            throw declareError(ref.identifier.value)
        }
    }

    private static func classAsgDeclaration(
        environment: Environment<String, ClassReference>,
        canDeclare: (String) -> Bool
    ): (ClassDeclWithRef) -> Unit {
        { classDecl: ClassDeclWithRef =>
            let ref: ClassReference = classDecl.ref
            if (canDeclare(classDecl.identifier.value)) {
                environment.declare(classDecl.identifier.value, ref)
                return
            }
            throw declareError(ref.identifier.value)
        }
    }

    private static func canDeclare(predicates: Array<(String) -> Bool>): (String) -> Bool {
        { key => predicates.iterator().all({ p => p(key) }) }
    }

    private static func declareError(name: String): Exception {
        Exception("Cannot declare ${name}")
    }
}