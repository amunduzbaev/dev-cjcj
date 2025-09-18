package cjcj.test

import cjcj.asg.typeChecker.TypeChecker
import cjcj.asg.AsgMaker
import cjcj.visitor.Program
import cjcj.parser
import cjcj.scanner.*
import cjcj.prettyPrinter.PrettyPrinter

import std.env.*
import std.collection.ArrayList

@Test
class TypeCheckTests {

    private func getAsg(test: String): Program {
        let scanner = Scanner(test.toRuneArray())
        let tokens = scanner.scanTokens().toArray()

        let reporter = parser.Reporter(getStdErr(), tokens.toArray())
        let parser: parser.Parser = parser.Parser(tokens.toArray(), reporter)
        let program: ?Program = parser.parse()
        if (let Some(p) <- program) {
            return AsgMaker().resolve(p)
        }
        @Fail("Couldn't parse the program")
    }

    @TestCase
    func typeVarDecl_test() {
        let testWrong: String = """
            main() {
                let a: Int64 = "string"
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))

        let testRight: String = """
            main() {
                let a: Int64 = 2543
            }
            """
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func typeVarAssign_test() {
        let testWrong: String = """
            main() {
                var a: Int64 = 5
                a = "string"
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
        let testRight: String = """
            main() {
                var a: Int64 = 5
                a = 16
            }
            """
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func operatorsType_test() {
        let testWrong: String = """
            main() {
                var a: Int64 = 5
                let b: String = "5"
                a = a + b
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
        let testRight: String = """
            main() {
                var a: Int64 = 5
                let b: Int64 = 10
                a = a + b
            }
            """
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func typeFuncDecl_test() {
        let testWrong: String = """
            main() {
                func a(): Int64 {
                    "string"
                }
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
        let testRight: String = """
            main() {
                func a(): Int64 {
                    10
                }
            }
            """
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func typeMainDecl_test() {
        let testWrong: String = """
            main(): Int64 {
                "string"
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
        let testRight: String = """
            main(): Int64 {
                5
            }
            """
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func typeFuncParams_test() {
        let testWrong: String = """
            main() {
                func a(b: String, c: Int64): Int64 {
                    6
                }
                a(2, "1")
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
        let testRight: String = """
            main() {
                func a(b: String, c: Int64): Int64 {
                    6
                }
                a("1", 2)
            }
            """
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func typeInferenceIfElse_test() {
        // TODO: If you're here because this failed, remember that this is not valid code LOL, when
        // we made this test we didn't have all those fancy interfaces and keywords that you, people
        // of the future have, so please don't get angry and just change this small piece of code :)
        let testWrong: String = """
            class a {}
            class b {}
            class c <: b & a {}
            class d <: b & a {}
            main() {
                if (true) {
                    return c()
                } else {
                    return d()
                }
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
        let testRight: String = """
            main() {
                func a(b: String, c: Int64): Int64 {
                    6
                }
                a("1", 2)
            }
            """
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func ifConditionBool_test() {
        // TODO: If you're here because this failed, remember that this is not valid code LOL, when
        // we made this test we didn't have all those fancy interfaces and keywords that you, people
        // of the future have, so please don't get angry and just change this small piece of code :)
        let testWrong: String = """
            main() {
                if (1 + 2) {
                }
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
        let testRight: String = """
            main() {
                if(true) {
                }
            }
            """
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func correctFunctionFinding_test() {
        let testRight: String = """
            main() {
                func a(b: Int64, c: Int64): Unit {
                    ()
                }
                if (true) {
                    func a(b: Int64, c: Int64): Unit {
                        ()
                    }
                }
                a(1, 1)
            }
            """
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func differentScopeFunctionFinding_test() {
        let test: String = """
            func A(a: Any, b: Any): Any {
                a
            }
            func A(a: Int64, b: Any): Int64 {
                a
            }
            main(args: Int64) {
                let a: Int64 = 1
                let b: Int64 = 2
                if (true) {
                    func A(a: Any, b: Int64): Int64 {
                        b
                    }
                }

                let c = A(a, b)
            }
            """
        TypeChecker(getAsg(test))
    }

    @TestCase
    func multipleCandidateFunction_test() {
        let test: String = """
            func A(a: Any, b: Any): Any {
                a
            }

            func A(a: Int64, b: Any): Int64 {
                a
            }

            func A(a: Any, b: Int64): Int64 {
                2
            }

            main(args: Int64) {
                let a: Int64 = 1
                let b: Int64 = 2

                let c = A(a, b)
            }
            """

        @AssertThrows[Exception](TypeChecker(getAsg(test)))
    }

    @TestCase
    func noSuitableFunctionReturnType_test() {
        let test: String = """
            func A(a: Any, b: Any): Any {
                a
            }

            func A(a: Any, b: Int64): Int64 {
                2
            }
            main(args: Int64) {
                let a: Int64 = 1
                let b: Int64 = 2

                let c: String
                c = A(a, b)
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(test)))
    }

    @TestCase
    func memberAccessFound_test() {
        let testRight: String = """
            class a {
                let b: Int64
                init() {
                }
                func f() {
                }
            }
            main(){
                let b = a()
                let c: Int64 = a().b
                let f: Unit = b.f()
            }"""
        TypeChecker(getAsg(testRight))
        let testWrong: String = """
            class a {
                let b: Int64
                init() {
                }
                func f() {
                }
            }
            main(){
                let b = a()
                let c: String = b.b
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
    }

    @TestCase
    func needToposortFunctionCall_test() {
        let test: String = """
        func f() {
            g()
            i()
        }
        func i() {
            g()
        }
        func g() {
            h()
        }
        func h() {
            return 1
        }
        main(){
        }"""
        TypeChecker(getAsg(test))
    }

    @TestCase
    func cyclicFunctionCall_test() {
        let testRight: String = """
            func f() {
                g()
                return 5
            }

            func g(): String {
                f()
                return "hi"
            }
            main() {
            }"""
        TypeChecker(getAsg(testRight))
        let testWrong: String = """
            func f() {
                g()
                return 5
            }

            func g() {
                f()
                return "hi"
            }
            main() {
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
    }

    @TestCase
    func memberAccessNotFound_test() {
        let test: String = """
            class a {
            }
            main(){
                let b = a()
                let c: Int64 = a().b
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(test)))
    }

    @TestCase
    func memberAccessCannotCallClass_test() {
        let test: String = """
            class a {
            }
            main(){
                let b: a = a()
                let c: Int64 = b()
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(test)))
    }

    @TestCase
    func memberShadowing_test() {
        let test: String = """
            class c {
                let cvar = 5
            }
            class b <: c {
                func bfunc() {
                }
            }
            class a <: b {
                let cvar = 19
                init() {
                }
            }
            main(){
                let a = a()
                let v: Int64 = a.cvar
                let f: Unit = a.bfunc()
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(test)))
    }

    @TestCase
    func noReturnInsideInit_test() {
        let test: String = """
            class a {
                init() {
                    return 5
                }
            }
            main(){
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(test)))
    }

    @TestCase
    func bodyMemberAccess_test() {
        let testRight: String = """
            class a {
                let b = 9
                init() {
                    b + 1
                    let c: Int64 = f()
                    func inside(): Int64 {
                        let a = 10
                        if (true) {
                            return 7
                        }
                        func insideinside(): String {
                            let a = "string"
                            return a
                        }
                        b
                    }
                }
                func f() {
                    return b
                }
            }
            main(){
                let test = a()
            }"""
        TypeChecker(getAsg(testRight))
    }

    @TestCase
    func memberAccessSuperClass_test() {
        let testRight: String = """
            class c {
                let cvar = 5
            }
            class b <: c {
                func bfunc() {
                }
            }
            class a <: b {
                init() {
                }
            }
            main(){
                let a = a()
                let v: Int64 = a.cvar
                let f: Unit = a.bfunc()
            }"""
        TypeChecker(getAsg(testRight))
        let testWrong: String = """
            class c {
                let common = 5
            }
            class b <: c {
                func bfunc() {
                }
            }
            class a <: b {
                init() {
                }
            }
            main(){
                let a = a()
                let v: String = a.common
                let f: Unit = a.bfunc()
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
    }
}
