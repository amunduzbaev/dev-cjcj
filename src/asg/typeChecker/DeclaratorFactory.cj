package cjcj.asg.typeChecker

import cjcj.visitor.*
import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import cjcj.parser.NodeIdManager
import cjcj.asg.declarator.Declarator

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
        Declarator(
            visitFunc: functionDeclaration(funcEnvironment),
            visitVar: variableDeclaration(variableEnvironment),
            canDeclare: canDeclare([
                { k => funcEnvironment.getLocal(k).isNone() },
                { k => variableEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    public static func globalDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        classEnvironment: Environment<String, ClassReference>
    ): Declarator {
        Declarator(
            visitFunc: functionDeclaration(funcEnvironment),
            visitClass: classDeclaration(classEnvironment),
            canDeclare: canDeclare([
                { k => funcEnvironment.getLocal(k).isNone() },
                { k => classEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    public static func functionDeclarator(
        funcEnvironment: Environment<String, FuncReference>
    ): Declarator {
        Declarator(
            visitFunc: functionDeclaration(funcEnvironment),
            canDeclare: canDeclare([
                { k => funcEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    public static func functionTypeDeclarator(
        funcEnvironment: Environment<String, FuncReference>,
        typeManager: TypeManager
    ): Declarator {
        ReferenceDeclarator(
            visitFunc: functionTypeDeclaration(funcEnvironment, typeManager),
            canDeclare: canDeclare([
                { k => funcEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    public static func variableDeclarator(
        variableEnvironment: Environment<String, VariableReference>
    ): Declarator {
        Declarator(
            visitVar: variableDeclaration(variableEnvironment),
            canDeclare: canDeclare([
                { k => variableEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    public static func classDeclarator(
        classEnvironment: Environment<String, ClassReference>
    ): Declarator {
        Declarator(
            visitClass: classDeclaration(classEnvironment),
            canDeclare: canDeclare([
                { k => classEnvironment.getLocal(k).isNone() }
            ])
        )
    }

    private static func variableDeclaration(
        environment: Environment<String, VariableReference>
    ): (VarDecl) -> ?Reference {
        { varDecl: VarDecl =>
            let ref: VariableReference = VariableReference(NodeIdManager.nextId(), 
                varDecl.identifier, varDecl.keyword)
            if (canDeclare({ k => environment.getLocal(k).isNone() })(varDecl.identifier.value)) {
                environment.declare(varDecl.identifier.value, ref)
            }
            ref
        }
    }

    private static func functionDeclaration(
        environment: Environment<String, FuncReference>
    ): (FuncDecl) -> ?Reference {
        { funcDecl: FuncDecl =>
            let ref: FuncReference = FuncReference(NodeIdManager.nextId(), funcDecl.identifier)
            let funcName: String = funcDecl.identifier.value
            // let params: Array<Type> = funcDecl.params.iterator()
            //     .map({ p => Type(p.paramType.typeName.value) })
            //     .fold<ArrayList<Type>>(ArrayList(), { acc, v => acc.add(v); acc }).toArray()
            // let funcHashParamName: String = TypeManager.funcHashConcat(funcName, params)
            if (canDeclare({ k => environment.getLocal(k).isNone() })(funcName)) {
                environment.declare(funcName, ref)
            }
            ref
        }
    }

    private static func functionTypeDeclaration(
        environment: Environment<String, FuncReference>,
        typeManager: TypeManager
    ): (FuncDeclWithRef) -> ?Reference {
        { funcDeclWithRef: FuncDeclWithRef =>
            let ref: FuncReference = funcDeclWithRef.funcRef
            let funcName: String = ref.identifier.value
            // TODO: ADD AN HELPER CLASS WITH FUNCPARAM TO PARAMREF
            ref.paramRef.getOrThrow().iterator().enumerate().forEach({ p =>
                p[1].effectiveType = typeManager.get(funcDeclWithRef.params[p[0]].paramType.typeName.value) })
            let params: Array<Type> = ref.paramRef.getOrThrow().iterator()
                .map({ p => p.effectiveType.getOrThrow() })
                .fold<ArrayList<Type>>(ArrayList(), { acc, v => acc.add(v); acc }).toArray()
            let funcHashParamName: String = TypeManager.funcHashConcat(funcName, params)
            typeManager.addFunction(ref)
            if (canDeclare({ k => environment.getLocal(k).isNone() })(funcHashParamName)) {
                environment.declare(funcHashParamName, ref)
            }
            ref
        }
    }

    private static func classDeclaration(
        environment: Environment<String, ClassReference>
    ): (ClassDecl) -> ?Reference {
        { classDecl: ClassDecl =>
            let ref: ClassReference = ClassReference(NodeIdManager.nextId(), classDecl.identifier)
            if (canDeclare({ k => environment.getLocal(k).isNone() })(classDecl.identifier.value)) {
                environment.declare(classDecl.identifier.value, ref)
            }
            ref
        }
    }

    private static func canDeclare(predicates: Array<(String) -> Bool>): (String) -> Bool {
        { key => predicates.iterator().all({ p => p(key) }) }
    }

}