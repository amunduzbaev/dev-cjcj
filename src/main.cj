package CangjieCompiler

import std.fs.*
import std.env.*

import std.io.*
import std.collection.*
import std.process.*
import std.reflect.*

main(): Int64 {
    let bytes = File.readFrom("src/testcode.txt")

    let source = String.fromUtf8(bytes)
    
    let scanner = Scanner(source.toRuneArray())
    let tokens = scanner.scanTokens()

    for(token in tokens) {
        println(token)
    }

    return 0

}