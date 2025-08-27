package cjcj.parser

import cjcj.scanner.Token
import cjcj.scanner.TokenKind
import std.collection.*
import std.ast.Position
import cjcj.ast.*

import std.env.ConsoleWriter

public class Reporter {
    private let console: ConsoleWriter
    private let errors: ArrayList<Error> = ArrayList()

    public Reporter(console: ConsoleWriter, private let tokens: Array<Token>) {
        this.console = console
    }

    private func getSuffixPrefix(current: Int64): (String, String) {
        var prefix: String = ""
        var suffix: String = ""
        for(i in max(current-9,0)..current) {
            if(tokens[i].pos.line == tokens[current].pos.line) {
                prefix += tokens[i].value + " "
            }
        }
        for(i in current+1..min(current+10,tokens.size)) {
            if(tokens[i].pos.line == tokens[current].pos.line) {
                suffix += tokens[i].value + " "
            }
        }
        //remove the first two characters of the line because it's a NL '\n'
        return (prefix[2..], suffix)
    }

    func error(token: Token, message: String, index: Int64) {
        if (token.kind == TokenKind.END) {
            errors.add(Error(Int64(token.pos.line), index, "end", message, getSuffixPrefix(index)))
        } else {
            errors.add(Error(Int64(token.pos.line), index, token.value, message, getSuffixPrefix(index)))
        }
    }

    func consumeError(token: Token, index: Int64, expected: TokenKind, found: String) {
        if (token.kind == TokenKind.END) {
            errors.add(Error(Int64(token.pos.line), index, "end", 
            "expected '${redify(expected.toString())}', found ${redify("end")}", getSuffixPrefix(index)))
        } else {
            errors.add(Error(Int64(token.pos.line), index, token.value, 
            "expected '${redify(expected.toString())}', found '${redify(found.toString())}'", getSuffixPrefix(index)))
        }
    }

    public func logErrors() {
        if (errors.size > 0) {
            for(i in 0..(min(errors.size,5))) {
                console.write(errors[i].report())
            }
            console.write(
                """

${errors.size} errors generated, ${min(errors.size,5)} errors printed.
Failed to parse program.
"""
            )
        }
    }

}

private struct Error {

    Error(private let line: Int64, private let index: Int64, 
        private let wher: String, private let message: String, 
        private let suffixPrefix: (String, String)) {}

    public func report(): String {
        let lineStr: String = line.toString()
            let spaces: String = " "*lineStr.size
            return """
\u{001b}[31m
error\u{001b}[0m: ${message}
${spaces} |
${lineStr} | ${suffixPrefix[0]}${redify(wher)} ${suffixPrefix[1]}
${spaces} | ${" " * suffixPrefix[0].size}^
            """
            

    }
}

private func redify(str: String) {
        return "\u{001b}[31m${str}\u{001b}[0m"
    }