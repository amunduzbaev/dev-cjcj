package cjcj.asg

import cjcj.visitor.*
import std.env.getStdOut
import std.collection.HashSet
import std.collection.HashMap
import std.collection.ArrayList

public open class AssignExprError <: ASGError { }
public open class FuncParamError <: ASGError { }
public open class VarDeclError <: ASGError { }
public open class ReturnExprError <: ASGError { }
public open class CallExprError <: ASGError { }
public open class ASGError <: Exception { }


