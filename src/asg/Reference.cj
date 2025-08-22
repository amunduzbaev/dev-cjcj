package cjcj.asg

import cjcj.ast.Node
import cjcj.ast.Expr
import cjcj.ast.Block
import cjcj.ast.TypeNode
import cjcj.ast.FuncParam
import cjcj.ast.Argument
import cjcj.ast.NodeId
import cjcj.ast.Visitor
import cjcj.prettyPrinter.PrettyPrinter
import cjcj.scanner.Token

import std.collection.ArrayList

/*
* Reference nodes represent variable references inside the ASG, they are still
* nodes but with specific data needed from the ASG.
*/
public open class Reference <: Node {
    /*
    TODO: the identifier will become an expression and in general all the
    * references will be checked by hashing the toString of the expression that
    * is calling, this is important because it can happen that I call a function
    * from a member access (a.b()) and I need to differenciate between them
    * (b() must be different from a.b()).
    */
    private let identifier_: Token
    private let declType_: ?TypeNode
    // private let effectiveType

    private var value_: ?Node

    public Reference(id: NodeId, identifier: Token, declType: ?TypeNode, value: ?Node) {
        super(id)
        identifier_ = identifier
        declType_ = declType
        value_ = value
    }

    public override open func prettyPrint(printer: PrettyPrinter): Unit {
        printer.append(identifier.value)
    }

    public override func traverse<R>(_: Visitor<R>): R {
        throw UnsupportedException("Unimplemented method")
    }

    public prop identifier: Token {
        get() { identifier_ }
    }

    public prop declType: ?TypeNode {
        get() { declType_ }
    }

    public mut prop value: Node {
        get() { match(value_) {
            case Some(v) => v
            case _ => throw UnsupportedException("Uninitialised value")
        } }
        set(v) { value_ = v}
    }
}

class VariableReference <: Reference {
    public VariableReference(id: NodeId, identifier: Token, declType: ?TypeNode, value: Expr) {
        super(id, identifier, declType, value)
    }
}

class FuncReference <: Reference {
    private let environment_: Environment
    private let params_: ArrayList<FuncParam>

    public FuncReference(id: NodeId, identifier: Token, declType: ?TypeNode,
        value: Block, environment: Environment, params: ArrayList<FuncParam>) {
        super(id, identifier, declType, value)
        environment_ = environment
        params_ = params
    }

    public override func prettyPrint(printer: PrettyPrinter): Unit {
        super.prettyPrint(printer)
        printer.append("(")
        if (!params.isEmpty()) {
            environment.get(params[0].name).value.prettyPrint(printer)
            params.iterator()
                .enumerate()
                .filter({ a => a[0] > 0})
                .map({ a => a[1] })
                .forEach({a =>
                    printer.append(", ")
                    environment.get(a.name).value.prettyPrint(printer)
                })
        }
        printer.append(")")
    }

    public prop environment: Environment {
        get() { environment_ }
    }

    public prop params: ArrayList<FuncParam> {
        get() { params_ }
    }
}
