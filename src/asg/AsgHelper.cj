package cjcj.asg

import cjcj.scanner.Token
import stdx.effect.Command

public open class AssignExprError <: ASGError { }
public open class FuncParamError <: ASGError { }
public open class VarDeclError <: ASGError { }
public open class ReturnExprError <: ASGError { }
public open class CallExprError <: ASGError { }
public open class ASGError <: Exception { }


public class NoBlock <: Command<Unit> {
    NoBlock(public let name: Token) { }
}