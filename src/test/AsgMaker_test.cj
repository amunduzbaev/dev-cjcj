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
class AsgMakerTests {
    @TestCase
    func asgMakerTest1() {
        let test: String = """
            main(args: Int64) {
                func aa(b: Int64, h: String): Int64 {
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
                } else {
                    "test-string"
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
        let asgMaker = AsgMaker()

        @Assert(program.isSome())
        if(let Some(p) <- program) {
            @AssertThrows[Exception](asgMaker.resolve(p))
        }
    }
}


