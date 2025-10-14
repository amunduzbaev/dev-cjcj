package cjcj.asg

import cjcj.scanner.Token
import cjcj.visitor.*
import cjcj.scanner.*

import std.collection.HashSet
import std.collection.ArrayList
import std.collection.HashMap
import stdx.effect.Command

// import cjcj.parser.NodeIdManager
// import std.ast.Position

public open class AssignExprError <: ASGError { }
public open class FuncParamError <: ASGError { }
public open class VarDeclError <: ASGError { }
public open class ReturnExprError <: ASGError { }
public open class CallExprError <: ASGError { }
public open class ASGError <: Exception { }


public class NoBlock <: Command<Unit> {
    NoBlock(public let name: Token) { }
}

public class ExistingReference <: Command<?Reference> {
}

public class WaitingDeclaration <: Command<?(VariableReference, TypeNode)> {}

public class IsVar <: Command<Unit> {
    IsVar(public let isVar: Bool) {}
}

class ClassEnvironment <: Command<Unit> {
    ClassEnvironment(public let environments: AsgEnvironments) {
    }
}

class DeclarationsTopSort <: Visitor<Unit> {
    private let visited = HashSet<Int64>()
    private let idToRef = HashMap<Int64, Reference>()
    private let classDecls = HashMap<String, ClassDecl>()
    private let order = ArrayList<(Decl, ?Reference)>()

    public func resolve(decls: ArrayList<(Decl, ?Reference)>) {
        decls.iterator().forEach({d => 
            match (d[1]) {
                case Some(ref) =>
                    idToRef.add(d[0].id.id, ref)
                    ()
                case _ => ()
            }

            match (d[0] as ClassDecl) {
                case Some(classDecl) => 
                    classDecls.add(classDecl.identifier.value, classDecl)
                case _ => ()
            }
        })

        decls.iterator().forEach({ d => 
            try {
                d[0].traverse(this)
            } handle(isVar: IsVar) {
                if (isVar.isVar) { resume with () }
            }
        })

        decls.iterator().forEach({d => 
            try { 
                d[0].traverse(this)
            } handle(isVar: IsVar) {
                if (!isVar.isVar) { resume with () }
            }
        })

        order
    }

    public override func visit(varDecl: VarDecl) {
        perform IsVar(true)
        order.add((varDecl, idToRef.get(varDecl.id.id)))   
    }

    public override func visit(funcDecl: FuncDecl) {
        perform IsVar(false)
        order.add((funcDecl, idToRef.get(funcDecl.id.id)))
    }

    public override func visit(mainDecl: MainDecl) {
        perform IsVar(false)
        order.add((mainDecl, idToRef.get(mainDecl.id.id)))
    }

    public override func visit(classDecl: ClassDecl) {
        if (visited.contains(classDecl.id.id)) {
            return ()
        }

        match (classDecl.superTypes.get(0)) {
            case Some(parent) => 
                tryVisitClass(parent.typeName.value)
            case _ => ()
        }

        perform IsVar(false)
        order.add((classDecl, idToRef.get(classDecl.id.id)))
    }

    public override func visit(interfaceDecl: InterfaceDecl) {
        perform IsVar(false)
        order.add((interfaceDecl, idToRef.get(interfaceDecl.id.id)))
    }

    private func tryVisitClass(name: String) {
        match (classDecls.get(name)) {
            case Some(classDecl) => 
                classDecl.traverse(this)
            case _ => ()
        }
    }
}

class AsgEnvironments {
    public let classEnvironment: Environment<String, ClassReference> 
    public let funcEnvironment: Environment<String, FuncReference> 
    public let variableEnvironment: Environment<String, VariableReference> 
    public let interfaceEnvironment: Environment<String, InterfaceReference> 

    public let currentScopeType: ScopeType
    public let currentGlobalType: GlobalType
    public let enclosing: ?AsgEnvironments

    init(enclosing: AsgEnvironments, newScopeType: ScopeType, newGlobalType: GlobalType) {
        classEnvironment = enclosing.classEnvironment
        interfaceEnvironment = enclosing.interfaceEnvironment

        funcEnvironment = Environment(enclosing.funcEnvironment)
        variableEnvironment = Environment(enclosing.variableEnvironment)

        currentScopeType = newScopeType
        currentGlobalType = newGlobalType
        this.enclosing = enclosing
    }

    init() {
        classEnvironment = Environment()
        interfaceEnvironment = Environment()

        funcEnvironment = Environment()
        variableEnvironment = Environment()

        currentScopeType = ScopeType.NIL
        currentGlobalType = GlobalType.NIL
        this.enclosing = None
    }

    public func declareVar(identifier: Token, value: VariableReference): Unit {
        let name: String = identifier.value
        if ((variableEnvironment.isGlobal && classEnvironment.getLocal(name).isSome()) ||
            funcEnvironment.getLocal(name).isSome())
        {
            throw Exception("Redefinition of declaration ${name}")
        }
        variableEnvironment.declare(identifier.value, value)
    }

    public func declareFunc(identifier: Token, value: FuncReference): Unit {
        if (funcEnvironment.getLocal(identifier.value).isNone()) {
            funcEnvironment.declare(identifier.value, value)
        }
    }

    public func isTypeDeclared(typeName: Token): Bool {
        classEnvironment.getGlobal(typeName.value).isSome() || 
        interfaceEnvironment.getGlobal(typeName.value).isSome()
    }

    // TODO : figure out what to do with the References of the function.
    public func get(key: String): Reference {
        var tmpFuncEnv = funcEnvironment
        var tmpVarEnv = variableEnvironment
        while (!tmpFuncEnv.isGlobal && !tmpVarEnv.isGlobal) {
            if (let Some(fun) <- tmpFuncEnv.getLocal(key)) {
                // THIS IS NOT THE REAL REFERENCE, IT'S JUST A WAY TO SAY THAT IT EXISTS.
                return fun
            }
            if (let Some(va) <- tmpVarEnv.getLocal(key)) {
                return va
            }
            tmpFuncEnv = tmpFuncEnv.enclosing.getOrThrow()
            tmpVarEnv = tmpVarEnv.enclosing.getOrThrow()
        }
        if (let Some(clas) <- classEnvironment.getLocal(key)) {
            return clas
        }
        if (let Some(fun) <- tmpFuncEnv.getLocal(key)) {
            // THIS IS NOT THE REAL REFERENCE, IT'S JUST A WAY TO SAY THAT IT EXISTS.
            return fun
        }
        if (let Some(va) <- tmpVarEnv.getLocal(key)) {
            return va
        }

        // IF THE REFERENCE WITH THIS KEY DOES NOT EXISTS, THE TYPE CHECKER WILL OBSERVE THIS ERROR
        // Current "temporary" solution is to have a default reference to a function in case no 
        // reference can be found. This is done to include case when we access function from super
        // type in a sub type (where we can have multiple super types which are interfaces)
        // return FuncReference(NodeIdManager.nextId(), 
        //     Token(TokenKind.IDENTIFIER, key, Position(0, 0, 0)))
        throw Exception("${key} is undefined.")
    }

    public func isGlobal(): Bool {
        funcEnvironment.isGlobal && variableEnvironment.isGlobal
    }
}

