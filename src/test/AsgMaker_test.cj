package cjcj.test

import cjcj.asg.AsgMaker
import cjcj.visitor.Program
import cjcj.parser
import cjcj.scanner.*
import cjcj.prettyPrinter.PrettyPrinter
import cjcj.asg.InitCheck.InitCheck

import std.env.*
import std.collection.ArrayList

@Test
class AsgMakerTests {
    private func getAst(test: String): Program {
        let scanner = Scanner(test.toRuneArray())
        let tokens = scanner.scanTokens().toArray()

        let reporter = parser.Reporter(getStdErr(), tokens.toArray())
        let parser: parser.Parser = parser.Parser(tokens.toArray(), reporter)
        let program: ?Program = parser.parse()
        if (let Some(p) <- program) {
            return p
        }
        @Fail("Couldn't parse the program")
    }

    @TestCase 
    func variableReference() {
        let testWrong: String = """
            main(){
                let b = a
            }
        """
        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))

        let testRight: String = """
            main(){
                let a = 5
                let b = a
            }
        """

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func functionReference() {
        let testWrong: String = """
            main(){
                let b = f(1, 2)
            }
        """
        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))

        let testRight: String = """
            main(){
                func f(a: Int64, b: Int64) {
                    a
                }
                let b = f(1, 2)
            }
        """

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func recursiveFunction() {
        let testWrong: String = """
            main(){
                func f() {
                    g()
                    1
                }
            }
        """
        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))

        let testRight: String = """
            main(){
                func f() {
                    f()
                    1
                }
            }
        """

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func unorderedDeclarations() {
        let testWrong: String = """
            func f(){
                a
            }
            let a = 5
            main(){
            }
        """
        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))

        var testRight: String = """
            let a = f()
            func f(){
                5
            }
            main(){
            }
        """

        AsgMaker().resolve(getAst(testRight))

        testRight = """
            func g() {
                f()
            }
            func f(){
                g()
                5
            }
            main(){
            }
        """

        AsgMaker().resolve(getAst(testRight))

        testRight = """
            func g() {
                C()
            }

            class C{
            }
            main(){
            }
        """

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func selfInitClass() {
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

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func unorderedClassDeclaration() {
        var testRight: String = """
            class B <: A{
            }
            class A {
            }
            main(){
            }
        """

        AsgMaker().resolve(getAst(testRight))

        // var testWrong: String = """
        //     class A {
        //     }
        //     main(){
        //         class B <: A{
        //         }
        //     }
        // """

        // @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))
    }

    @TestCase
    func referenceReuse() {
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

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase
    func builtinTypes() {
        var testRight: String = """
        main() {
            func a(b: String, c: Any): Int64 {
                1
            }

            a("2", 1)
        }
        """

        AsgMaker().resolve(getAst(testRight))

        var testWrong: String = """
        main() {
            func a(b: UndeclaredType): Int64 {
                1
            }

            a("String")
        }
        """

        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))
    }

    @TestCase
    func customTypes() {
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

        AsgMaker().resolve(getAst(testRight))

        var testWrong: String = """
        class T{
        }

        func f(a: T, b: K): Int64{
            1
        }

        main() {
            f(T(), K())
        }
        """

        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))
    }

    @TestCase
    func asgMakerTest1() {
        let test: String = """
            main(args: Int64) {
                func aa(b: Int64, h: Int32): Int64 {
                    4
                    return 6; 1 + 3
                }
                var a = if (true) {
                    "a"
                } else {
                    5
                }
                var b = while (true) {
                    1 + 3
                }
                aa(2, "1")
            } 
            """

        let scanner = Scanner(test.toRuneArray())
        let tokens = scanner.scanTokens().toArray()

        let reporter = parser.Reporter(getStdErr(), tokens.toArray())
        let parser: parser.Parser = parser.Parser(tokens.toArray(), reporter)
        let program: ?Program = parser.parse()
        let asgMaker = AsgMaker()

        @Assert(program.isSome())
        if(let Some(p) <- program) {
            asgMaker.resolve(p)
        }
    }

    @TestCase
    func asgMakerTest2() {
        let test: String = """
            class Type{
            }
            
            main(args: Int32){
                let a: Int32
                func A (a: Type, b: Type, c: Type){
                    a = 1
                    b = a + c

                    if(true) {
                        return a;
                    } else {
                    }
                    
                    return a;

                    a + b
                }

                a = if(true) {
                    2
                } else {
                    "test-string"
                }

                let b = a + a
                let c = a - a

                a = 3
                a = 5.2
                a = (a * c + (b - c)) ** 3

                A()
                A(1, 2, "test-param")
            }
            /*
                Some comment
                3(*&#@71I#(@))))))
            */
            """

        let scanner = Scanner(test.toRuneArray())
        let tokens = scanner.scanTokens().toArray()

        let reporter = parser.Reporter(getStdErr(), tokens.toArray())
        let parser: parser.Parser = parser.Parser(tokens.toArray(), reporter)
        let program: ?Program = parser.parse()
        let asgMaker = AsgMaker()

        @Assert(program.isSome())
        if(let Some(p) <- program) {
            asgMaker.resolve(p)
            // @AssertThrows[Exception]()
        }
    }
}


