package cjcj.test

import cjcj.asg.typeChecker.TypeChecker
import cjcj.asg.AsgMaker
import cjcj.visitor.Program
import cjcj.parser
import cjcj.scanner.*

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
    func builtinOperators_test() {
        let testWrong: String = """
            main() {
                let a: Bool = true
                let b: Bool = false

                a / b 
                a - b 
                a & b 
            }
        """

        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))

        let testRight: String = """
            main() {
                let a = 1
                let b = 2

                a % b 
                a / b 
                a - b 
                a & b 

                let c: Bool = true
                let d: Bool = false

                c && d
                c || d 
                c == d 
                c != d
                !c 
            }
        """

        TypeChecker(getAsg(testRight))
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
    func functionReturnTypeInferred_test() {
        let testRight: String = """
            func a(a: Int64) {
                2
            }
            func a(a: Any) {
                "string"
            }
            main(){
                let c: String = a(1)
            }
            """
        TypeChecker(getAsg(testRight))
        let testWrong: String = """
            func a(a: Int64) {
                "string"
            }
            main(){
                func a(a: Int64) {
                    2
                }
                let c: String = a(1)
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
    }


    @TestCase
    func noReturnInsideInit_test() {
        let testWrong: String = """
            class a {
                init() {
                    return 5
                }
            }
            main(){
            }
            """
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
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
    func nestedUnknownTypeFunctionCall_test() {
        let test: String = """
        class a {
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
        }
        func f() {
            g(String())
            i()
        }
        func i() {
            g(String())
        }
        func g(a: Any) {
            h()
        }
        func g(a: String) {
        }
        func h() {
            return 1
        }
        main(){
        }"""
        TypeChecker(getAsg(test))
        // TODO: We can make this test not fail if we let the assigner go into the blocks. It will
        // mean implement all the empty visit functions but it could be worth it, cjc doesn't do it.
        let testHard = """
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
        let a = 5
        func h() {
            func bo(): Int64 {
                f()
            }
            return a
        }
        main(){
        }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testHard)))
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
    func functionCallsParameters_test() {
        var test: String = """
            let a = g(1 + 2 * 4, "abcd")
            func g(a: Int64, b: String) {
            }
            main(){
            }"""
        TypeChecker(getAsg(test))
        test = """
            class a {
                func f() {
                    g(1 + 2 * 4, "abcd")
                }
                func g(a: Int64, b: String) {
                }
            }
            main(){
            }"""
        TypeChecker(getAsg(test))
        test = """
            main(){
                func g(a: Int64, b: String) {
                }
                func f() {
                    g(1 + 2 * 4, "abcd")
                }
            }"""
        TypeChecker(getAsg(test))
    }

    @TestCase
    func literalImplicitCast_test() {
        // ** needs to take a UInt64 on the right side.
        let testRight: String = """
            main(){
                1 + 2 * 4 ** 10
                let a: Int32 = 5
                let b: Float32 = 10.67
                let c: Int32 = 1 + 1
            }"""
        TypeChecker(getAsg(testRight))
        var testWrong: String = """
            main(){
                1 + 2 * 4 ** -10
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
        testWrong = """
            main(){
                let a: Int32 = 1.5
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
        testWrong = """
            main(){
                let a: Float32 = 1
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
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
    func memberAccessMultipleOverloads_test() {
        let test: String = """
            class a {
                func f(a: Int64, b: Any): Unit { }
                func f(a: Any, b: Any): Int64 { 1 }
                func f(a: Any, b: Int64): Int64 { 1 }
            }
            main(){
                let b: a = a()
                let c: Int64 = b.f(1, 1)
            }"""
        TypeChecker(getAsg(test))
    }

    @TestCase
    func functionWrongReturnType_test() {
        var test: String = """
            class a {
                func f(): Int64 { }
            }
            main(){
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(test)))
        test = """
            func f(): Int64 { }
            main(){
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(test)))
    }

    @TestCase
    func functionClassName_test() {
        var test: String = """
            func Any() {}
            main(){ }"""
        @AssertThrows[Exception](TypeChecker(getAsg(test)))
    }

    @TestCase
    func memberShadowing_test() {
        let testFunc: String = """
            class c {
                let cvar = 5
                func f() {
                }
            }
            class a <: b {
                func f() {
                }
                init() {
                }
            }
            class b <: c {
                func bfunc() {
                }
            }
            main(){
                let a = a()
                let v: Int64 = a.cvar
                let f: Unit = a.bfunc()
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testFunc)))
        let testVar: String = """
            class c {
                let cvar = 5
            }
            class a <: b {
                let cvar = 2
                init() {
                }
            }
            class b <: c {
                func bfunc() {
                }
            }
            main(){
                let a = a()
                let v: Int64 = a.cvar
                let f: Unit = a.bfunc()
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testVar)))
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

    @TestCase
    func variableDeclCycle_test() {
        let testRight: String = """
            let a: Int64 = f()
            func f() {
                return a
            }
            main(){
            }"""
        TypeChecker(getAsg(testRight))
        let testWrong: String = """
            let a = f()
            func f() {
                return a
            }
            main(){
            }"""
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
    }

    @TestCase
    func contextTypeInference_test() {
        let testRight: String = """
            func F(a: Int64): String {
                "One"
            }

            func F(a: Any): Int64 {
                1
            }

            func sum(a: Int64, b: Int64) {
                a + b
            }

            main(){
                sum(F(1), F(1))
            }
            """
        
        TypeChecker(getAsg(testRight))
    }

    @TestCase 
    func complexContextTypeInference_test() {
        let testRight: String = """
            class A {
                func a() {

                }
            }
            class B {
                let a: Int64 = 1
            }
            func F(a: Int64) {
                B()
            }
            func F(a: Any) {
                A()
            }
            func dbl(a: Int64) {
                a + a
            }
            main() {
                let c: Int64 = F(1).a
                let d = dbl(F(1).a)
            }        
            """

        TypeChecker(getAsg(testRight))

        let testWrong: String = """
            class A {
                let a: Int64 = 1
            }
            class B {
                func a() {
                }
            }

            func F(a: Int64) {
                B()
            }

            func F(a: Any) {
                A()
            }
            func dbl(a: Int64) {
                a + a
            }

            main() {
                let c: Int64 = F(1).a
                let d = dbl(F(1).a)
            }
            """

        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))

        let testRightHard: String = """
            class D {}
            class C <: D {}
            class B <: D {}
            func A(a: Int64, b: Any): B { B() }
            func A(a: Any, b: Any): Int64 { 1 }

            func G(a: Int64): C { C() }
            func G(a: Any): Int64{ 1 }

            func sum(a: Int64, b: Int64) {
                a + b
            }

            main(){
                let c = sum (1, if ( true ) { A(1, 1) } else { G(1) })
                let d = if ( true ) { A(1, 1) } else { G(1) } + 1
                let e: Int64 = if ( true ) { A(1, 1) } else { G(1) } 
                let f = if ( true) { A(1, 1) } else { G(1) }
            }

            // The type of f should be D, since best match for A(1, 1) has type B and best match for G(1) has
            // type C, where the lowest common supertype of B and C is D
            """

        TypeChecker(getAsg(testRightHard))
    }

    @TestCase
    func distinctClassesMemberFunctionsOverload_test() {
        let testRight = """
            class A{
                func G(a: Int64) {
                    a
                }
            }

            class B{
                func G(a: Int64) {
                    "String"
                }
            }

            func F(a: Int64) {
                A()
            }
            func F(a: Any) {
                B()
            }

            main(){
                let c = F(1).G(1)           // OK (Type of c should be Int64)
            }
        """

        let testWrong = """
            class A{
                func G(a: Int64) {
                    a
                }
            }

            class B{
                func G(a: Int64) {
                    "String"
                }
            }

            func F(a: Int64) {
                A()
            }
            func F(a: Any) {
                B()
            }

            main(){
                let d: String = F(1).G(1)   // ERR (Should not be able to infer the type)
            }
        """

        TypeChecker(getAsg(testRight))
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
    }

    @TestCase
    func returnBestMatchAssignment_test() {
        let testRight = """
            class A {
            }
            class B {
            }

            func F(a: Any) {
                B()
            }

            func F(a: Int64) {
                A()
            }

            func F2() {
                if(true) {
                    return F(1)
                } else {
                    return A()
                }
            }

            main(){
                let a: A = F2()
            }
        """

        let testWrong = """
            class A {
            }
            class B {
            }

            func F(a: Any) {
                A()
            }

            func F(a: Int64) {
                B()
            }

            func F2() {
                if(true) {
                    return F(1)
                } else {
                    return A()
                }
            }

            main(){
                let a: A = F2()
            }
        """

        TypeChecker(getAsg(testRight))
        @AssertThrows[Exception](TypeChecker(getAsg(testWrong)))
    }
}
