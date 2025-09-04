package cjcj.test

import cjcj.asg.AsgMaker
import cjcj.visitor.Program
import cjcj.parser
import cjcj.scanner.*
import cjcj.prettyPrinter.PrettyPrinter
import cjcj.asg.InitCheck

import std.env.*
import std.collection.ArrayList

@Test
class ParserTests {
    @TestCase
    func parseTest1() {
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

        @Assert(program.isSome())
    }


    @TestCase
    func parseTest2() {
        let test: String = """
            main(args: Bp){
                let a: Int32
                func A ()
                    a = 1
                }

                a = 2

                let b = a +

                a = 3.
            }
            
            """

        let scanner = Scanner(test.toRuneArray())
        let tokens = scanner.scanTokens().toArray()
        
        let reporter = parser.Reporter(getStdErr(), tokens.toArray())
        let parser: parser.Parser = parser.Parser(tokens.toArray(), reporter)

        let program: ?Program = parser.parse()

        // let CorrectError = ArrayList<()>()

        @Assert(program.isNone())
        // @Assert(reporter.getError == CorrectError)
    }

    @TestCase 
    func parseTest3() {
        let test: String = """
            main(args: Bp){
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
                } else if( boolean == 2 ) {
                    "test-string"
                } else {
                    A()
                }

                let b = a + a

                a = 3
                a = 5.2
                a = (a * c + (d - e)) ** 3

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

        // parser.logErrors()

        // let printer = PrettyPrinter()
        // if(let Some(p) <- program) {
        //     p.prettyPrint(printer)
        // }
        // println(printer.toString())

        @Assert(program.isSome())
    }
}


