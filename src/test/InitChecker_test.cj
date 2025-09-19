package cjcj.test

import cjcj.asg.typeChecker.TypeChecker
import cjcj.asg.AsgMaker
import cjcj.asg.initChecker.*
import cjcj.visitor.Program
import cjcj.parser
import cjcj.scanner.*
import cjcj.prettyPrinter.PrettyPrinter

import std.env.*
import std.collection.ArrayList

@Test
class InitCheckerTests {
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
    
    private func getAsg(test: String): Program {
        let asg = AsgMaker().resolve(getAst(test))
        TypeChecker(asg)
        asg
    }

    @TestCase 
    func variableReference_test() {
        let testWrong: String = """
            main() {
                let a: Int64
                let b = a
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            main() {
                let a: Int64 = 1
                let b = a
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }

    @TestCase 
    func ifelseInitialization_test() {
        let testWrong: String = """
            main() {
                let a: Int64
                if (true) {
                    a = 1
                }                
                let b = a
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            main() {
                let a: Int64
                if (true) {
                    a = 1
                } else {
                    a = 3
                }
                
                let b = a
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }


    @TestCase 
    func ifelseInitializationComplex_test() {
        var testWrong: String = """
            main() {
                let a: Int64
                if (true) {
                    a = 1
                } else if (true) {
                    a = 2
                } else {
                }
                
                let b = a
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        testWrong = """
            main() {
                let a: Int64
                while (true) {
                    if (true) {
                        a = 1
                    } else {
                        a = 2
                    }
                }
                
                let b = a
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            main() {
                let a: Int64
                if (true) {
                    a = 1
                } else if (true) {
                    a = 2
                } else {
                    a = 3
                }
                
                let b = a
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }


    @TestCase
    func ifelseInitializationComplex2_test() {
        let testWrong: String = """
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

        @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            main () {
                let A: Int64

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

        InitChecker().resolve(getAsg(testRight))
    }

    @TestCase 
    func blockInitialization_test() {
        let testWrong: String = """
            main() {
                let a: Int64
                while(true){
                    a = 1
                }
                
                let b = a
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            main() {
                let a: Int64
                while(true){
                    a = 1
                }
                a = 2
                
                let b = a
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }

    @TestCase 
    func declarationInitialization_test() {
        let testRight: String = """
            main() {
                let a: Int64 = 1
                let b = a
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }



    @TestCase 
    func mutation_test() {
        let testWrong: String = """
            main() {
                let a: Int64 = 1
                a = 2
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            main() {
                var a: Int64 = 1
                a = 2
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }

    @TestCase
    func mutationComplex_test() {
        let testWrong: String = """
            main() {
                let a: Int64 = 1
                if (true) {
                    a = 2
                }
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            main() {
                var a: Int64 = 1
                if (true) {
                    a = 2
                }
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }


    @TestCase
    func mutationComplex2_test() {
        let testWrong: String = """
            main () {
                let A: Int64

                if(true) {
                    A = 3
                } else {
                    A = 1
                    if(true) {
                    } else {
                        A = 2
                    }
                }
            }
            """

        @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            main () {
                var A: Int64

                if(true) {
                    A = 3
                } else {
                    A = 1
                    if(true) {
                    } else {
                        A = 2
                    }
                }
            }
            """

        InitChecker().resolve(getAsg(testRight))
    }

    @TestCase
    func initializationInsideFunctions_test() {
        let testWrong: String = """
            main() {
                let a: Int64
                func F() {
                    a = 2
                }
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            main() {
                var a: Int64 = 1
                func F() {
                    a = 2
                }
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }


    @TestCase
    func classInit_test() {
        let testWrong: String = """
            class C{
                let a: Int64
                init() {
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            class C{
                let a: Int64
                init() {
                    a = 1
                }
            }
            main() {
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }


    @TestCase
    func classInitMultiVar_test() {
        let testWrong: String = """
            class C{
                let a: Int64 = 1
                let b: Int64
                init() {
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            class C{
                let a: Int64 = 1
                let b: Int64
                init() {
                    b = 2
                }
            }
            main() {
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }

    @TestCase
    func classInitFunctionCall_test() {
        let testWrong: String = """
            class C{
                let b: Int64
                init() {
                    F()
                    b = 2
                }

                func F() {
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            class C{
                let b: Int64
                init() {
                    b = 2
                    F()
                }

                func F() {
                }
            }
            main() {
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }


    @TestCase
    func classInitFunctionCallinVarDecl_test() {
        let testWrong: String = """
            class C{
                let b: Int64 = F()
                init() {
                }

                func F() {
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))
    }


    @TestCase
    func classInitMutation_test() {
        let testWrong: String = """
            class C{
                let b: Int64 = 1
                init() {
                    b = 2
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            class C{
                var b: Int64 = 1
                init() {
                    b = 2
                }
            }
            main() {
            }
        """

       InitChecker().resolve(getAsg(testRight))
    }


    @TestCase
    func classInitMutationComplex_test() {
        let testWrong: String = """
            class C{
                let b: Int64 = 1
                init() {
                }

                func F() {
                    b = 2
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](InitChecker().resolve(getAsg(testWrong)))

        let testRight: String = """
            class C{
                var b: Int64 = 1
                init() {
                }

                func F() {
                    b = 2
                }
            }
            main() {
            }
        """

       InitChecker().resolve(getAsg(testRight))
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
        @AssertThrows[Exception](InitChecker().resolve(getAsg(test)))
    }
}


