package cjcj.asg

import cjcj.scanner.Token
import cjcj.visitor.*
import cjcj.scanner.*
import std.collection.HashSet
import std.collection.ArrayList
import std.collection.HashMap
import stdx.effect.Command
import std.deriving.Derive

// import cjcj.parser.NodeIdManager
// import std.ast.Position

public open class AssignExprError <: ASGError {}

public open class FuncParamError <: ASGError {}

public open class VarDeclError <: ASGError {}

public open class ReturnExprError <: ASGError {}

public open class CallExprError <: ASGError {}

public open class ASGError <: Exception {}

@Derive[Equatable]
public enum DeclType {
    VAR | FUNC | CLASS | INTERFACE
}

public class NoBlock <: Command<Unit> {
    NoBlock(public let name: Token) {}
}

public class ExistingReference <: Command<?Reference> {}

public class WaitingDeclaration <: Command<?VariableReference> {}

public class DeclNode <: Command<Unit> {
    DeclNode(public let declType: DeclType, public let name: String) {}
}

class BodyEnvironment <: Command<Unit> {
    BodyEnvironment(public let environments: AsgEnvironments) {
    }
}

class TypeDeclaration<T> <: Visitor<Unit> {
    private let visited = HashSet<Int64>()
    private let idMap = HashMap<Int64, T>()
    private let typeDecls = HashMap<String, Decl>()
    private var order = ArrayList<Decl>()

    /* for a list of declarations, returns the declarations with the following reordering
     * 1) Variable declarations are in front
     * 2) The order of type declarations (class/interface) are in topological order in terms of
     * inheritance
     * 3) typeDecls maps the names of types to the declaration node of that type
     */
    public func resolve(decls: ArrayList<(Decl, ?T)>): ArrayList<(Decl, ?T)> {
        decls.iterator().forEach(
            {
                d =>
                    if (let Some(ref) <- d[1]) {
                        idMap.add(d[0].id.id, ref)
                    }

                    try {
                        d[0].traverse(this)
                    } handle (declNode: DeclNode) {
                        if (declNode.declType == DeclType.CLASS || declNode.declType == DeclType.INTERFACE) {
                            typeDecls.add(declNode.name, d[0])
                        }
                    }
            }
        )

        decls.iterator().forEach({
            d => try {
                d[0].traverse(this)
            } handle (declNode: DeclNode) {
                if (declNode.declType == DeclType.VAR) {
                    resume with () 
                }
            }
        })

        decls.iterator().forEach({
            d => try {
                d[0].traverse(this)
            } handle (declNode: DeclNode) {
                if (!(declNode.declType == DeclType.VAR)) {
                    resume with () 
                }
            }
        })

        order.iterator().fold(
            ArrayList<(Decl, ?T)>(),
            {
                acc, decl =>
                    acc.add((decl, idMap.get(decl.id.id)))
                    acc
            }
        )
    }

    public override func visit(varDecl: VarDecl) {
        perform DeclNode(DeclType.VAR, varDecl.identifier.value)
        order.add(varDecl)
    }

    public override func visit(funcDecl: FuncDecl) {
        perform DeclNode(DeclType.FUNC, funcDecl.identifier.value)
        order.add(funcDecl)
    }

    public override func visit(mainDecl: MainDecl) {
        perform DeclNode(DeclType.FUNC, "main")
        order.add(mainDecl)
    }

    public override func visit(classDecl: ClassDecl) {
        perform DeclNode(DeclType.CLASS, classDecl.identifier.value)
        if (visited.contains(classDecl.id.id)) {
            return ()
        }
        visited.add(classDecl.id.id)

        classDecl.superTypes.iterator().forEach({
            superType => tryVisit(superType.typeName.value)
        })

        order.add(classDecl)
    }

    public override func visit(interfaceDecl: InterfaceDecl) {
        perform DeclNode(DeclType.INTERFACE, interfaceDecl.identifier.value)
        if (visited.contains(interfaceDecl.id.id)) {
            return ()
        }
        visited.add(interfaceDecl.id.id)

        interfaceDecl.superTypes.iterator().forEach({
            superType => tryVisit(superType.typeName.value)
        })

        order.add(interfaceDecl)
    }

    private func tryVisit(name: String) {
        match (typeDecls.get(name)) {
            case Some(decl) => decl.traverse(this)
            case _ => ()
        }
    }

    public func getSuperTypes(typeDecl: Decl): ArrayList<Decl> {
        order = ArrayList<Decl>()
        visited.clear()

        try {
            typeDecl.traverse(this)
        } handle (_: DeclNode) {
            resume with ()
        }

        order
    }
}

class AsgEnvironments {
    public let classEnvironment: Environment<String, ClassReference>
    public let funcEnvironment: Environment<String, FuncReference>
    public let variableEnvironment: Environment<String, VariableReference>
    public let interfaceEnvironment: Environment<String, InterfaceReference>
    public let exactFunctions = HashSet<String>()

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
            funcEnvironment.getLocal(name).isSome()) {
            throw Exception("Redefinition of declaration ${name}")
        }
        variableEnvironment.declare(identifier.value, value)
    }

    public func declareFunc(identifier: Token, value: FuncReference): Unit {
        if (funcEnvironment.getLocal(identifier.value).isNone()) {
            funcEnvironment.declare(identifier.value, value)
        }
    }

    public func declareExactFunc(funcDecl: FuncDecl) {
        exactFunctions.add(Utils.funcHashConcat(funcDecl))
    }

    public func checkExactFunc(funcHash: String) {
        exactFunctions.contains(funcHash)
    }

    public func isTypeDeclared(typeName: Token): Bool {
        classEnvironment.getGlobal(typeName.value).isSome() || interfaceEnvironment.getGlobal(typeName.value).isSome()
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

        throw Exception("${key} is undefined.")
    }

    public func getInterface(key: String): InterfaceReference {
        interfaceEnvironment.getLocal(key).getOrThrow({=> Exception("Interface ${key} does not exist")})
    }

    public func isGlobal(): Bool {
        funcEnvironment.isGlobal && variableEnvironment.isGlobal
    }
}
