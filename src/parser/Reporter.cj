package cjcj.parser

import std.env.ConsoleWriter

// Temporary imports to not have compilation errors.
import std.ast.Token
import std.ast.TokenKind

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

    func error(line: Int64, message: String) {
        report(line, "", message)
    }

    private func report(line: Int64, wher: String, message: String) {
        console.writeln(
            "[line " + line.toString() + "] Error" + wher + ": " + message)
    }
}