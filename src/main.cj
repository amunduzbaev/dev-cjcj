package cjcj

import cjcj.ast.Node
import cjcj.parser.Parser
import cjcj.parser.Reporter

import std.env.*
import std.io.*
import std.fs.File

// Temporary imports to not have compilation errors.
import std.ast.Token
import std.ast.TokenKind

public class Cj {
    static var hadError: Bool = false
    static var hadRuntimeError: Bool = false

    public static func runFile(path: String) {
        let bytes: Array<Byte> = File.readFrom(path)
        run(String.fromUtf8(bytes))

        if (hadError) {
            exit(65)
        }
        if (hadRuntimeError) {
            exit(70)
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
        // getStdOut().writeln(source)
        // let scanner = Scanner(source)
        // let tokens = scanner.scanTokens()

        let tokens: Array<Token> = [
            Token(TokenKind.INTEGER_LITERAL, "10"),
            Token(TokenKind.ADD),
            Token(TokenKind.INTEGER_LITERAL, "5"),
            Token(TokenKind.END)
        ]

        let parser: Parser = Parser(tokens.toArray(), Reporter(getStdErr()))
        let nodes: ?Array<Node> = parser.parse()

        if (let Some(nodes) <- nodes) {
            for (node in nodes) {
                println(node.prettyPrint(indent: 0))
            }
        }

        // if (hadError) { return }
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
    // testAstPrinter()
    // if (args.size > 1) {
    //     getStdOut().writeln("Usage: cjlox [script]")
    //     exit(64)
    // } else if (args.size == 1) {
    //     println(args[0])
    //     Cj.runFile(args[0])
    // } else {
    //     Cj.runPrompt()
    // }
    Cj.runFile("cjpm.lock")
}