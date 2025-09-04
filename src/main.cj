package cjcj

import cjcj.asg.AsgMaker
import cjcj.asg.typeChecker.TypeChecker
import cjcj.visitor.Program
import cjcj.parser.*
import cjcj.scanner.*
import cjcj.prettyPrinter.PrettyPrinter

import std.env.*
import std.io.*
import std.fs.File 


public class Cj {
    static var hadError: Bool = false

    public static func runFile(path: String) {
        let bytes: Array<Byte> = File.readFrom(path)
        run(String.fromUtf8(bytes))

        if (hadError) {
            exit(65)
        }
    }

    private static func run(source: String) {
        let scanner = Scanner(source.toRuneArray())
        let tokens = scanner.scanTokens().toArray()

        let parser: Parser = Parser(tokens.toArray(), Reporter(getStdErr(), tokens.toArray()))
        let program: ?Program = parser.parse()
        let printer: PrettyPrinter = PrettyPrinter()
        let asgMaker = AsgMaker()
        let asg: Program
        parser.logErrors()
        if (let Some(p) <- program) {
            asg = asgMaker.resolve(p)
            TypeChecker(asg)
            asg.prettyPrint(printer)
            println(printer.toString())
        }
    }
}

main (args: Array<String>) {
    if (args.size > 1) {
        getStdOut().writeln("Usage: cjcj [script]")
        exit(64)
    } else if (args.size == 1) {
        println(args[0])
        Cj.runFile(args[0])
    } else {
        // This is for debug
        Cj.runFile("testcode.txt")
    }
}