package cjcj.test

import cjcj.asg.AsgMaker
import cjcj.asg.InitCheck
import cjcj.visitor.Program
import cjcj.parser
import cjcj.scanner.*
import cjcj.prettyPrinter.PrettyPrinter

import std.env.*
import std.collection.ArrayList

@Test
class InitCheckTests {
    @TestCase
    func initCheckTest1() {
        let test: String = """
            main(args: Bp){
                let a: Int32
                func A (){
                    a = 1
                }

                a = 2

                let b = a + a

                a = 3
            }"""

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

            @Assert(!initChecker.notInitialized.isEmpty() && 
                    !initChecker.cannotMutate.isEmpty())
        }
    }

    @TestCase
    func initCheckTest2() {
        let test: String = """
            main () {
                let A: Int32

                if(true) {
                    A = 3

                } else {
                    if(true) {
                        A = 5
                    } else {
                    }
                }

                if(true) {
                } else {
                    A = 4
                }

                A = 1
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
        }
    }

    @TestCase
    func initCheckTest3() {
        let test: String = """
            main () {
                let A: Int32

                if(true) {
                    A = 3

                } else {
                    if(true) {
                        A = 5
                    } else {
                    }
                }

                if(true) {
                } else {
                    A = 4
                }

                let B = A
                A = 1
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

            @Assert(!initChecker.notInitialized.isEmpty() && 
                    initChecker.cannotMutate.isEmpty())
        }
    }

    @TestCase
    func initCheckTest4() {
        let test: String = """
            main () {
                let A: Int32

                if(true) {
                    A = 3

                } else {
                    if(true) {
                        A = 5
                    } else {
                        A = 2
                    }
                }

                if(true) {
                    A = 5
                } else {
                }

                let B = A

                A = 1
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
                    !initChecker.cannotMutate.isEmpty())
        }
    }
}


