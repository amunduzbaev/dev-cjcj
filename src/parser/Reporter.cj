package cjcj.parser

import cjcj.scanner.Token
import cjcj.scanner.TokenKind

import std.env.ConsoleWriter

public class Reporter {
    private let console: ConsoleWriter

    public init (console: ConsoleWriter) {
        this.console = console
    }

    func error(token: Token, message: String) {
        if (token.kind == TokenKind.END) {
            report(Int64(token.pos.line), " at end", message)
        } else {
            report(Int64(token.pos.line), " at '" + token.value + "'", message)
        }
    }

    private func report(line: Int64, wher: String, message: String) {
        console.writeln(
            "[line " + line.toString() + "] Error" + wher + ": " + message)
    }
}