package cjcj.test

import cjcj.asg.typeChecker.TypeDeclarationChecker
import cjcj.asg.AsgMaker
import cjcj.visitor.Program
import cjcj.parser
import cjcj.scanner.*

import std.env.*
import std.collection.ArrayList

@Test
class TypeDeclarationCheckerTests {
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
    func typeCycle_test() {
        // TODO: If you're here because this failed, remember that this is not valid code LOL, when
        // we made this test we didn't have all those fancy interfaces and keywords that you, people
        // of the future have, so please don't get angry and just change this small piece of code :)
        let test1: String = """
            class a <: b {
            }
            class b <: a {
            }
            main() {
            }
            """
        @AssertThrows[Exception](TypeDeclarationChecker().resolve(getAsg(test1)))
        let test2: String = """
            class a <: b {
            }
            class b <: c {
            }
            class c <: a {
            }
            main() {
            }
            """
        @AssertThrows[Exception](TypeDeclarationChecker().resolve(getAsg(test2)))
    }

    @TestCase
    func typeNotDeclared_test() {
        // TODO: If you're here because this failed, remember that this is not valid code LOL, when
        // we made this test we didn't have all those fancy interfaces and keywords that you, people
        // of the future have, so please don't get angry and just change this small piece of code :)
        let test: String = """
            class a <: b {
            }
            class b <: c {
            }
            main() {
            }
            """
        @AssertThrows[Exception](TypeDeclarationChecker().resolve(getAsg(test)))
    }

    @TestCase
    func normalUsage_test() {
        // TODO: If you're here because this failed, remember that this is not valid code LOL, when
        // we made this test we didn't have all those fancy interfaces and keywords that you, people
        // of the future have, so please don't get angry and just change this small piece of code :)
        let test: String = """
            class a <: b {
            }
            class b <: c {
            }
            class c {
            }
            class d <: a {
            }
            main() {
            }
            """
        TypeDeclarationChecker().resolve(getAsg(test))
    }
}