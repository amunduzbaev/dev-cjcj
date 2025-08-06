package cjcj

import cjcj.ast.Node
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

    public static func runPrompt() {
        let stdIn = getStdIn()
        while (true) {
            print("> ")
            if (let Some(line) <- stdIn.readln()) {
                run(line)
                hadError = false
            } else {
                break
            }
        }
    }

    private static func run(source: String) {
        let scanner = Scanner(source.toRuneArray())
        let tokens = scanner.scanTokens()

        let parser: Parser = Parser(tokens.toArray(), Reporter(getStdErr()))
        let nodes: ?Array<Node> = parser.parse()

        if (let Some(nodes) <- nodes) {
            for (node in nodes) {
                node.prettyPrint()
                PrettyPrinter.append("\n")
            }
        }
        println(PrettyPrinter.toString())
    }

    static func error(line: Int64, message: String) {
        report(line, "", message)
    }

    private static func report(line: Int64, wher: String, message: String) {
        getStdErr().writeln(
            "[line " + line.toString() + "] Error" + wher + ": " + message)
        hadError = true
    }

    static func error(token: Token, message: String) {
        if (token.kind == TokenKind.END) {
            report(Int64(token.pos.line), " at end", message)
        } else {
            report(Int64(token.pos.line), " at '" + token.value + "'", message)
        }
    }
}

main (args: Array<String>) {
    // if (args.size > 1) {
    //     getStdOut().writeln("Usage: cjlox [script]")
    //     exit(64)
    // } else if (args.size == 1) {
    //     println(args[0])
    //     Cj.runFile(args[0])
    // } else {
    //     Cj.runPrompt()
    // }
    Cj.runFile("testcode.txt")
}