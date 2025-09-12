package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager

import std.env.getStdOut

import std.ast.Position
import std.collection.ArrayList
import std.collection.ArrayStack
import std.collection.Map
import std.collection.HashMap
import std.deriving.Derive

private class ReferenceDeclarator <: Declarator {
    public ReferenceDeclarator(
        canDeclare!: (String) -> Bool = { _ => true },
        private let visitVar!: (VarDeclWithRef) -> ?Reference = { _ => None },
        private let visitFunc!: (FuncDeclWithRef) -> ?Reference = { _ => None },
        private let visitClass!: (ClassDeclWithRef) -> ?Reference = { _ => None },
        private let visitMain!: (MainDeclWithRef) -> ?Reference = { _ => None }
    ) {
        super(canDeclare: canDeclare)
    }

    public override func visit(funcDeclWithRef: FuncDeclWithRef): ?Reference {
        visitFunc(funcDeclWithRef)
    }
    
    public override func visit(varDeclWithRef: VarDeclWithRef): ?Reference {
        visitVar(varDeclWithRef)
    }

    public override func visit(classDeclWithRef: ClassDeclWithRef): ?Reference {
        visitClass(classDeclWithRef)
    }

    public override func visit(mainDeclWithRef: MainDeclWithRef): ?Reference {
        visitMain(mainDeclWithRef)
    }
}

// TODO: THE CAN DECLARE SEEMS TO BE WRONG LOOK AT IT.
public abstract class DeclaratorFactory {
    public static func bodyDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        variableEnvironment: Environment<String, VariableReference>
    ): Declarator {
        let canDeclare: (String) -> Bool = canDeclare([
            { k => variableEnvironment.getLocal(k).isNone() }
        ])
        Declarator(
            visitFunc: functionDeclaration(funcEnvironment, canDeclare),
            visitVar: variableDeclaration(variableEnvironment, canDeclare),
            canDeclare: canDeclare
        )
    }

    public static func globalDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        classEnvironment: Environment<String, ClassReference>
    ): Declarator {
        let canDeclare: (String) -> Bool = canDeclare([
            { k => classEnvironment.getLocal(k).isNone() }
        ])
        Declarator(
            visitFunc: functionDeclaration(funcEnvironment, canDeclare),
            visitClass: classDeclaration(classEnvironment, canDeclare),
            canDeclare: canDeclare
        )
    }

    public static func globalTypeDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        classEnvironment: Environment<String, ClassReference>,
        typeManager: TypeManager
    ): Declarator {
        let canDeclare: (String) -> Bool = canDeclare([
            { k => funcEnvironment.getLocal(k).isNone() },
            { k => classEnvironment.getLocal(k).isNone() }
        ])
        ReferenceDeclarator(
            visitFunc: functionTypeDeclaration(funcEnvironment, typeManager, canDeclare),
            canDeclare: canDeclare
        )
    }

    public static func functionDeclarator(
        funcEnvironment: Environment<String, FuncReference>
    ): Declarator {
        functionDeclarator(
            funcEnvironment, canDeclare([{ k => funcEnvironment.getLocal(k).isNone() }])
        )
    }

    public static func functionDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        canDeclare: (String) -> Bool
    ): Declarator {
        Declarator(
            visitFunc: functionDeclaration(funcEnvironment, canDeclare),
            canDeclare: canDeclare
        )
    }

    public static func functionTypeDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        typeManager: TypeManager
    ): Declarator {
        functionTypeDeclarator(funcEnvironment, typeManager, canDeclare([
            { k => funcEnvironment.getLocal(k).isNone() }
        ]))
    }

    public static func functionTypeDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        typeManager: TypeManager,
        canDeclare: (String) -> Bool
    ): Declarator {
        ReferenceDeclarator(
            visitFunc: functionTypeDeclaration(funcEnvironment, typeManager, canDeclare),
            canDeclare: canDeclare
        )
    }

    public static func variableDeclarator(
        variableEnvironment: Environment<String, VariableReference>
    ): Declarator {
        variableDeclarator(
            variableEnvironment, canDeclare([{ k => variableEnvironment.getLocal(k).isNone() }])
        )
    }

    public static func variableDeclarator(
        variableEnvironment: Environment<String, VariableReference>,
        canDeclare: (String) -> Bool
    ): Declarator {
        Declarator(
            visitVar: variableDeclaration(variableEnvironment, canDeclare),
            canDeclare: canDeclare
        )
    }

    public static func classDeclarator(
        classEnvironment: Environment<String, ClassReference>
    ): Declarator {
        classDeclarator(
            classEnvironment, canDeclare([{ k => classEnvironment.getLocal(k).isNone() }])
        )
    }

    public static func classDeclarator(
        classEnvironment: Environment<String, ClassReference>,
        canDeclare: (String) -> Bool
    ): Declarator {
        Declarator(
            visitClass: classDeclaration(classEnvironment, canDeclare),
            canDeclare: canDeclare
        )
    }

    private static func variableDeclaration(
        environment: Environment<String, VariableReference>,
        canDeclare: (String) -> Bool
    ): (VarDecl) -> ?Reference {
        { varDecl: VarDecl =>
            let ref: VariableReference = VariableReference(NodeIdManager.nextId(), 
                varDecl.identifier, varDecl.keyword)
            if (canDeclare(varDecl.identifier.value)) {
                environment.declare(varDecl.identifier.value, ref)
                return ref
            }
            throw declareError(varDecl.identifier.value)
        }
    }

    private static func functionDeclaration(
        environment: Environment<String, FuncReference>,
        canDeclare: (String) -> Bool
    ): (FuncDecl) -> ?Reference {
        { funcDecl: FuncDecl =>
            let ref: FuncReference = FuncReference(NodeIdManager.nextId(), funcDecl.identifier)
            let funcName: String = funcDecl.identifier.value
            if (canDeclare(funcName)) {
                if (environment.getLocal(funcName).isNone()) {
                    environment.declare(funcName, ref)
                }
                return ref
            }
            throw declareError(funcName)
        }
    }

    private static func functionTypeDeclaration(
        environment: Environment<String, FuncReference>,
        typeManager: TypeManager,
        canDeclare: (String) -> Bool
    ): (FuncDeclWithRef) -> ?Reference {
        { funcDeclWithRef: FuncDeclWithRef =>
            let ref: FuncReference = funcDeclWithRef.funcRef
            let funcName: String = ref.identifier.value
            let paramRef: ArrayList<VariableReference> = ref.paramRef.getOrThrow()
            TypeCheckerHelper.funcParamToParamRef(
                funcDeclWithRef.params, ref.paramRef.getOrThrow(), typeManager
            )
            let params: Array<Type> = TypeCheckerHelper.refToType(paramRef)
            let funcHashParamName: String = TypeManager.funcHashConcat(funcName, params)
            typeManager.addFunction(ref)
            if (canDeclare(funcHashParamName)) {
                environment.declare(funcHashParamName, ref)
                return ref
            }
            throw declareError(
                funcName +
                params.iterator().map({ p => p.name })
                    .reduce({ a, b => a + b}).getOrDefault({ => ""})
            )
        }
    }

    private static func classDeclaration(
        environment: Environment<String, ClassReference>,
        canDeclare: (String) -> Bool
    ): (ClassDecl) -> ?Reference {
        { classDecl: ClassDecl =>
            let ref: ClassReference = ClassReference(NodeIdManager.nextId(), classDecl.identifier)
            if (canDeclare(classDecl.identifier.value)) {
                environment.declare(classDecl.identifier.value, ref)
            }
            ref
        }
    }

    private static func canDeclare(predicates: Array<(String) -> Bool>): (String) -> Bool {
        { key => predicates.iterator().all({ p => p(key) }) }
    }

    private static func declareError(name: String): Exception {
        Exception("Cannot declare ${name}")
    }
}