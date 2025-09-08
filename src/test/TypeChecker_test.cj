package cjcj.test

import cjcj.asg.typeChecker.TypeChecker
import cjcj.asg.AsgMaker
import cjcj.asg.InitCheck.*
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
                if (expression) {
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
    func typeCheckTest1() {
        let test: String = """
            main(args: Int64) {
                func aa(b: Int64, h: Int64): Int64 {
                    4
                    return 6; 1 + 3
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
        let initChecker = InitCheck()

        @Assert(program.isSome())
        if(let Some(p) <- program) {
            let asg = asgMaker.resolve(p)
            initChecker.resolve(asg)

            @Assert(initChecker.notInitialized.isEmpty() && 
                    initChecker.cannotMutate.isEmpty())

            @AssertThrows[Exception](TypeChecker(asg))
        }
    }

    @TestCase
    func typeCheckTest2() {
        let test: String = """
            main () {
                let A: Int32
                let B: Int64 = 10

                if(true) {
                    A = 1

                } else {
                    if(true) {
                        A = 1 + B
                    } else {
                    }
                }

                if(true) {
                } else {
                    A = 3
                }

                A = 4
            }
            """

        let scanner = Scanner(test.toRuneArray())
        let tokens = scanner.scanTokens().toArray()

        let reporter = parser.Reporter(getStdErr(), tokens.toArray())
        let parser: parser.Parser = parser.Parser(tokens.toArray(), reporter)
        let program: ?Program = parser.parse()
        let asgMaker = AsgMaker()
        let initChecker = InitCheck()

        @Assert(program.isSome())
        if(let Some(p) <- program) {
            let asg = asgMaker.resolve(p)
            initChecker.resolve(asg)

            @Assert(initChecker.notInitialized.isEmpty() && 
                    initChecker.cannotMutate.isEmpty())

            @AssertThrows[Exception](TypeChecker(asg))
        }
    }

    @TestCase
    func typeCheckTest3() {
        let test: String = """
            main(args: Int64) {
                let a = if(true) {
                    1
                } else {
                    2
                }

                let c: Int32 = 4

                let b = a + c
            }
            """

        let scanner = Scanner(test.toRuneArray())
        let tokens = scanner.scanTokens().toArray()

        let reporter = parser.Reporter(getStdErr(), tokens.toArray())
        let parser: parser.Parser = parser.Parser(tokens.toArray(), reporter)
        let program: ?Program = parser.parse()
        let asgMaker = AsgMaker()
        let initChecker = InitCheck()

        @Assert(program.isSome())
        if(let Some(p) <- program) {
            let asg = asgMaker.resolve(p)
            initChecker.resolve(asg)

            @Assert(initChecker.notInitialized.isEmpty() && 
                    initChecker.cannotMutate.isEmpty())

            @AssertThrows[Exception](TypeChecker(asg))
        }
    }

    // Overloading check
    @TestCase
    func typeCheckTest4() {
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

        let scanner = Scanner(test.toRuneArray())
        let tokens = scanner.scanTokens().toArray()

        let reporter = parser.Reporter(getStdErr(), tokens.toArray())
        let parser: parser.Parser = parser.Parser(tokens.toArray(), reporter)
        let program: ?Program = parser.parse()
        let asgMaker = AsgMaker()
        // let initChecker = InitCheck()

        @Assert(program.isSome())
        if(let Some(p) <- program) {
            let asg = asgMaker.resolve(p)
            // initChecker.resolve(asg)

            // @Assert(initChecker.notInitialized.isEmpty() && 
            //         initChecker.cannotMutate.isEmpty())
            
            TypeChecker(asg)
        }
    }


    @TestCase
    func typeCheckTest5() {
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

        let scanner = Scanner(test.toRuneArray())
        let tokens = scanner.scanTokens().toArray()

        let reporter = parser.Reporter(getStdErr(), tokens.toArray())
        let parser: parser.Parser = parser.Parser(tokens.toArray(), reporter)
        let program: ?Program = parser.parse()
        let asgMaker = AsgMaker()
        // let initChecker = InitCheck()

        @Assert(program.isSome())
        if(let Some(p) <- program) {
            let asg = asgMaker.resolve(p)
            @AssertThrows[Exception](TypeChecker(asg))
        }
    }
}


