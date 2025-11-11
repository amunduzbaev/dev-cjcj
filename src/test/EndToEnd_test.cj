package cjcj.test

import cjcj.asg.typeChecker.TypeChecker
import cjcj.asg.AsgMaker
import cjcj.asg.initChecker.*
import cjcj.visitor.Program
import cjcj.parser
import cjcj.scanner.*
import std.env.*
import std.collection.ArrayList

@Test
class EndToEndTests {
    private func scan(test: String): Array<Token> {
        Scanner(test.toRuneArray()).scanTokens().toArray()
    }

    private func parse(test: String): ?Program {
        let tokens: Array<Token> = scan(test)
        parser.Parser(tokens, parser.Reporter(getStdErr(), tokens)).parse()
    }

    private func getAst(test: String): Program {
        let program = parse(test)
        if (let Some(p) <- program) {
            return p
        }
        @Fail("Couldn't parse the program")
    }

    private func run(test: String) {
        let asg = AsgMaker().resolve(getAst(test))

        InitChecker(TypeChecker(asg).typeEnvironment).resolve(asg)
    }

    @TestCase
    func builtinOperators_test() {
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
                ()
            }
        """

        run(testRight)
    }

    @TestCase
    func typeVarDecl_test() {
        let testRight: String = """
            main() {
                let a: Int64 = 2543
            }
            """
        run(testRight)
    }

    @TestCase
    func typeVarAssign_test() {
        let testRight: String = """
            main() {
                var a: Int64 = 5
                a = 16
            }
            """
        run(testRight)
    }

    @TestCase
    func operatorsType_test() {
        let testRight: String = """
            main() {
                var a: Int64 = 5
                let b: Int64 = 10
                a = a + b
            }
            """
        run(testRight)
    }

    @TestCase
    func typeFuncDecl_test() {
        let testRight: String = """
            main() {
                func a(): Int64 {
                    10
                }
            }
            """
        run(testRight)
    }

    @TestCase
    func typeMainDecl_test() {
        let testRight: String = """
            main(): Int64 {
                5
            }
            """
        run(testRight)
    }

    @TestCase
    func typeFuncParams_test() {
        let testRight: String = """
            main() {
                func a(b: String, c: Int64): Int64 {
                    6
                }
                a("1", 2)
            }
            """
        run(testRight)
    }

    @TestCase
    func typeInferenceIfElse_test() {
        // TODO: If you're here because this failed, remember that this is not valid code LOL, when
        // we made this test we didn't have all those fancy interfaces and keywords that you, people
        // of the future have, so please don't get angry and just change this small piece of code :)
        let testRight: String = """
            main() {
                func a(b: String, c: Int64): Int64 {
                    6
                }
                a("1", 2)
            }
            """
        run(testRight)
    }

    @TestCase
    func ifConditionBool_test() {
        // TODO: If you're here because this failed, remember that this is not valid code LOL, when
        // we made this test we didn't have all those fancy interfaces and keywords that you, people
        // of the future have, so please don't get angry and just change this small piece of code :)
        let testRight: String = """
            main() {
                if(true) {
                }
            }
            """
        run(testRight)
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
        run(testRight)
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
            main() {
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
        run(test)
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
        run(testRight)
    }

    @TestCase
    func memberAccessFound_test() {
        let testRight: String = """
            class a {
                let b: Int64
                init() {
                    b = 1
                }
                func f() {
                }
            }
            main(){
                let b = a()
                let c: Int64 = a().b
                let f: Unit = b.f()
            }
            """

        run(testRight)
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
        }
        """
        run(test)
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
            }
            """
        run(testRight)
    }

    @TestCase
    func functionCallsParameters_test() {
        var test: String = """
            let a = g(1 + 2 * 4, "abcd")
            func g(a: Int64, b: String) {
            }
            main(){
            }
            """
        run(test)
        test = """
            class a {
                func f() {
                    g(1 + 2 * 4, "abcd")
                }
                func g(a: Int64, b: String) {
                }
            }
            main(){
            }
            """
        run(test)
        test = """
            main(){
                func g(a: Int64, b: String) {
                }
                func f() {
                    g(1 + 2 * 4, "abcd")
                }
            }
            """
        run(test)
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
            }
            """
        run(testRight)
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
            }
            """
        run(test)
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
            }
           """
        run(testRight)
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
            }
           """
        run(testRight)
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

        run(testRight)
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

        run(testRight)

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

        run(testRightHard)
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

        run(testRight)
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

        run(testRight)
    }

    @TestCase
    func interfaceOverloadedFunctionCall_test() {
        var testRight = """
        func F(a: ToString): Int64 {
            1
        }

        func F(a: Hashable): Hashable {
            a
        }

        func G(a: ToString): ToString {
            a
        }

        func G(a: Hashable): Hashable {
            a
        }

        func toStr(a: ToString) {
            "String"
        }

        main() {
            let d = toStr(F(G(1)))      // ok
        }
        """

        run(testRight)

        testRight = """
        func F(a: Any): Int64 {
            1
        }

        func F(a: Hashable): Int64 {
            1
        }

        func F(a: ToString): ToString {
            "aa"
        }

        func G(a: ToString): ToString {
            a
        }
        func G(a: Hashable): Hashable {
            a
        }

        main() {
            let a: Hashable = F(G(1))
        }        
        """

        run(testRight)
    }

    @TestCase
    func interfaceOverloadedFunctionCall2_test() {
        var testRight = """
        func F(a: Any): Int64 {
            1
        }

        func F(a: Hashable): Hashable {
            a
        }

        func G(a: ToString): ToString {
            a
        }

        func G(a: Hashable): Hashable {
            a
        }

        func toStr(a: ToString) {
            "String"
        }

        main() {
            F(G(1))                     // ok (the type of the expression should be Hashable)

            let integer: Int64 = 1
            let a: Hashable = integer
            let c = F(G(a))             // ok
        }
        """

        run(testRight)
    }

    @TestCase
    func interfaceInheritanceFunctionCall_test() {
        var testRight = """
        interface A{}
        interface B{}
        interface C{}

        class D <: A & B{}
        class E <: D {}
        class H <: E {}
        class G <: H & A & B & C {}

        func F(a: D) {}
        func F(a: A) {}
        func F(a: B) {}

        main () {
            F(G())
        }        
        """

        run(testRight)
    }

    @TestCase
    func interfaceOverloadedFunctionCallComplex_test() {
        /* Explanation of tests checked here 

            // F(1) has a type a or b
            // G(1) has a type c or b
            // even if without any context best match for G(1) is c and best match for F(1) is a,
            // a and c can not have common supertype, hence both of them are chosen as b, since best match
            // for H is H(a: b)
         */
        var testRight = """
        interface T { }
        interface K { }
        class a <: T & K {}
        class b <: T {}
        class c <: T & K {}

        func F(c: Int64): a {
            a()
        }
        func F(c: Hashable): b {
            b()
        }

        func G(d: Int64): c {
            c()
        }

        func G(d: Hashable): b {
            b()
        }

        func H(a: b): Any {
            String()
        }

        func H(a: T): Int64 {
            1
        }

        main(){
            let v1 = H( if(true) { F(1) } else { G(1) } )            // ok
            let v2: b = if (true) { F(1) } else { G(1) }             // ok
            let v3: Int64 = H( if(true) { F(1) } else { G(1) } )     // ok
        }
        """

        run(testRight)
    }

    @TestCase
    func interfaceMemberAccess_test() {
        var testRight = """
        interface I {
            func f(): Int64
        }

        class C <: I {
            func f(): Int64 {
                1
            }
        }

        func g(): I{
            C()
        }

        main() {
            let a: I = C()
            a.f()

            g().f()
        }
        """

        run(testRight)
    }

    @TestCase
    func inheritedMemberAccess_test() {
        var testRight = """
        class S {
            func f() {
                1
            }
        }

        func f() {
            "str"
        }

        class C <: S {
            func g() {
                f()
            }
        }

        func g(): String{
            "str"
        }

        main() {
            let a: Int64 = C().g()
        }
        """

        run(testRight)
    }

    @TestCase
    func globalVariablesConsistency_test() {
        var testRight = """
        class C {
            func f() {
                func g(): Int64 {
                    1
                }

                g()
            }
        }
        main() {
        }
        """

        run(testRight)

        testRight = """
        class C{
            func f() {
                func g() {
                    "ff"
                }
                D().g()
            }
        }

        class D {
            func g() {
                1
            }
        }


        main() {
            let c: Int64 = C().f()
        }
        """

        run(testRight)
    }

    @TestCase
    func globalVariablesConsistencyComplex_test() {
        var testRight = """
        func k(a: Int64): Int64 {
            1
        }

        func f(){
            func k(a: Int64): String {
                "String"
            }

            h()
        }

        func h() {
            k(1)
        }

        main() {
            let a: Int64 = f()
        }
        """

        run(testRight)
    }

    @TestCase
    func NodeTraversalOrder_test() {
        var testRight = """
        class C {
            func f() {
                D().t()
            }

            func t() {
                1
            }
        }

        class D {
            func g() {
                C().t()
            }

            func t() {
                1
            }
        }

        main() {
        }
        """

        run(testRight)
    }

    // From AsgMaker

    @TestCase
    func variableReference_test() {
        let testRight: String = """
            main(){
                let a = 5
                let b = a
            }
        """

        run(testRight)
    }

    @TestCase
    func functionReference_test() {
        let testRight: String = """
            main(){
                func f(a: Int64, b: Int64) {
                    a
                }
                let b = f(1, 2)
            }
        """

        run(testRight)
    }

    @TestCase
    func recursiveFunction_test() {
        let testRight: String = """
            main(){
                func f():Int64 {
                    f()
                    1
                }
            }
        """

        run(testRight)
    }

    @TestCase
    func unorderedDeclarations_test() {
        var testRight: String = """
            let a = f()
            func f(){
                5
            }
            main(){
            }
        """

        run(testRight)

        testRight = """
            func g() {
                f()
            }
            func f(): Int64 {
                g()
                5
            }
            main(){
            }
        """

        run(testRight)

        testRight = """
            func g() {
                C()
            }

            class C{
            }
            main(){
            }
        """

        run(testRight)
    }

    @TestCase
    func selfInitClass_test() {
        var testRight: String = """
            class D{
                func F() {
                    let c = D()
                    1
                }
            }
            main(){
            }
        """

        run(testRight)
    }

    @TestCase
    func unorderedClassDeclaration_test() {
        var testRight: String = """
            class B <: A{
            }
            class A {
            }
            main(){
            }
        """

        run(testRight)
    }

    @TestCase
    func referenceReuse_test() {
        var testRight: String = """
        func f() {
            func h() {
                g()
            }

            h()
        }

        func g(){
            1
        }

        main(){
        }
        """

        run(testRight)
    }

    @TestCase
    func builtinTypes_test() {
        var testRight: String = """
        main() {
            func a(b: String, c: Any): Int64 {
                1
            }

            a("2", 1)
        }
        """

        run(testRight)
    }

    @TestCase
    func customTypes_test() {
        var testRight: String = """
        class T{
        }

        func f(a: T, b: K): Int64{
            1
        }

        class K{
        }

        main() {
            f(T(), K())
        }
        """

        run(testRight)
    }

    @TestCase
    func thisSuperExpression_test() {
        var testRight: String = """
        class T{
            var a: Int64 = 1

            func f() {
                this.a = 1
            }
        }
        main() {
        }
        """
        run(testRight)
    }

    @TestCase
    func interfaceDeclaration_test() {
        var testRight: String = """
        interface I {
            func f(a: Int64): Unit
            func sum(a: Int64, b: Int64): Int64 {
                a + b
            }
        }

        main() {
        }
        """

        run(testRight)
    }

    @TestCase
    func interfaceDeclarationComplex_test() {
        var testRight: String = """
        let c: Int64 = 1
        interface I {
            func sum(a: Int64, b: Int64): Int64 {
                a + b + c
            }
            func max_(a: Int64, b: Int64): Int64 {
                if(a > b && a > c) {
                    a
                } else if(b > c) {
                    b
                } else {
                    c
                }
            }
        }
        main() {
        }
        """

        run(testRight)
    }

    @TestCase
    func interfaceInstance_test() {
        var testRight: String = """
        interface I { }
        class C <: I { }
        main() {
            let c: I = C()
        }
        """

        run(testRight)
    }

    @TestCase
    func total_test() {
        let test: String = """
            main(args: Int64) {
                func aa(b: Int64, h: String): Int64 {
                    4
                    return 6;
                }
                var a = if (true) {
                    100
                } else {
                    5
                }
                var b = while (true) {
                    5
                }
                aa(2, "1")
            } 
            """
        run(test)
    }

    @TestCase
    func totalComplex_test() {
        let test: String = """
            class Type{
            }
            
            main(args: Int32){
                var a: Int32
                func A (a: Type, b: Type, c: Type){
                    if(true) {
                        return a;
                    } else {
                    }
                    
                    return b;

                    c
                }

                a = if(true) {
                    2
                } else {
                    5
                }

                let b = a + a
                let c = a - a

                a = 3
                a = (a * c + (b - c)) * 3

                A(Type(), Type(), Type())
            }
            """
        run(test)
    }

    /* If a class inherits a interface, it should implement all member functions of the interface */
    @TestCase
    func interfaceInheritanceFunctionRule_test() {
        var testRight = """
            interface I {
                func a(): Int64
            }
            class C <: I {
                func a() {
                    1
                }
            }

            main() {
            }
        """

        run(testRight)
    }

    /* If a class inherits a interface, it should implement all member functions of the interface */
    @TestCase
    func interfaceInheritanceFunctionRuleComplex_test() {
        var testRight = """
            interface J {
                func b(): Int64
            }
            interface I <: J {
                func a(): Int64
            }

            class C <: I {
                func a() { 1 }
                func b() { 1 }
            }

            main() {
            }
        """

        run(testRight)

        testRight = """
            interface I {
                func f(): Int64
            }
            interface J {
                func f(): Int64
            }

            class C <: I & J {
                func f() { 1 }
            }

            main() {
            }
        """

        run(testRight)
    }

    @TestCase
    func classInheritanceRule_test() {
        var testRight = """
            class S {
            }
            interface I {
            }

            class C <: S & I{
            }
            main() {
            }
        """

        run(testRight)
    }

    @TestCase
    func classInheritedMemberAccessRule_test() {
        var testRight = """
            class S {
                let a: Int64 = 1
            }
            interface I {
                func a(): Int64 {
                    1
                }
            }

            class C <: S & I {
                func a(): Int64 {
                    1
                }
            }

            main() {
            }
        """

        run(testRight)
    }
}
