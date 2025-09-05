package cjcj.test

import cjcj.asg.AsgMaker
import cjcj.visitor.*
import cjcj.parser
import cjcj.scanner.*
import cjcj.prettyPrinter.PrettyPrinter
import cjcj.asg.InitCheck

import std.env.*
import std.collection.ArrayList

@Test
class ParserTests {
    private func scan(test: String): Array<Token> {
        Scanner(test.toRuneArray()).scanTokens().toArray()  
    }

    private func parse(test: String): ?Program {
        let tokens: Array<Token> = scan(test)
        parser.Parser(tokens, parser.Reporter(getStdErr(), tokens)).parse()
    }

    private func getMain(test: String): MainDecl {
        let program = parse(test)
        @Assert(program.isSome())
        for (d in program.getOrThrow().decls) {
            if (let Some(m) <- (d as MainDecl)) {
                return m
            }
        }
        throw Exception("No main inside program")
    }

    @TestCase
    func mainDecl_test() {
        let test: String = """
            main(): Unit{
            }"""

        getMain(test)
    }

    @TestCase
    func mainDeclTooManyParams_test() {
        let test: String = """
            main(a: Int64, b: String): Unit{
            }"""

        @Assert(parse(test).isNone())
    }

    @TestCase
    func funcDecl_test() {
        let test: String = """
            main(){
                func a() {
                }
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDecl }))
    }

    @TestCase
    func funcDeclParams_test() {
        let test: String = """
            main(){
                func a(a: Int64, b: Unit, c: CustomType) {
                }
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDecl }))
        let decl: FuncDecl = (m.block.nodes[0] as FuncDecl).getOrThrow()
        @Assert(decl.params.size == 3)
    }

    @TestCase
    func funcDeclDeclType_test() {
        let test: String = """
            main(){
                func a(): Int64 {
                }
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDecl }))
        let decl: FuncDecl = (m.block.nodes[0] as FuncDecl).getOrThrow()
        @Assert(decl.declType.isSome())
    }

    @TestCase
    func funcDeclBlock_test() {
        let test: String = """
            main(){
                func a() {
                    let test = 3986
                    var b: String = "string"
                    while (condition) {
                        f()
                    }
                    if (true) {
                        return 9
                    }
                    return 6347
                }
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDecl }))
        let decl: FuncDecl = (m.block.nodes[0] as FuncDecl).getOrThrow()
        @Assert(decl.block.nodes.size == 5)
    }

    @TestCase
    func funcDeclGeneral_test() {
        let test: String = """
            main(){
                func a(a: Int64, b: Unit, c: CustomType): Int64 {
                    let bo = 5
                    if (condition) {
                        return 4
                    }
                    return 10
                }
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDecl }))
        let decl: FuncDecl = (m.block.nodes[0] as FuncDecl).getOrThrow()
        @Assert(decl.declType.isSome())
        @Assert(decl.params.size == 3)
    }

    @TestCase
    func classDecl_test() {
        let test: String = """
            class a {
            }
            main(){
            }"""

        let p: ?Program = parse(test)
        @Assert(p.isSome())
        let program = p.getOrThrow()
        @Assert(program.decls[0] is ClassDecl)
    }

    @TestCase
    func classDeclWithSupertypes_test() {
        let test: String = """
            class a <: b & c & d {
            }
            main(){
            }"""

        let p: ?Program = parse(test)
        @Assert(p.isSome())
        let program = p.getOrThrow()
        @Assert(program.decls[0] is ClassDecl)
        let classDecl = (program.decls[0] as ClassDecl).getOrThrow()
        @Assert(classDecl.superTypes.size == 3)
    }

    @TestCase
    func classDeclBody_test() {
        let test: String = """
            class a {
                let a = 6
                let b: Int64 = 347
                func a() {
                }
                init(a: CustomType) {
                }
            }
            main(){
            }"""

        let p: ?Program = parse(test)
        @Assert(p.isSome())
        let program = p.getOrThrow()
        @Assert(program.decls[0] is ClassDecl)
        let classDecl = (program.decls[0] as ClassDecl).getOrThrow()
        @Assert(classDecl.body.decls.size == 4)
    }

    @TestCase
    func varDecl_test() {
        let test: String = """
            main(){
                let a: Int32
                let b: Int64 = 567
                var a: Int32
                var b = 567
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is VarDecl }))
        let decls: ArrayList<VarDecl> = m.block.nodes.iterator()
            .map({ n => (n as VarDecl).getOrThrow() })
            .fold(ArrayList(), { res, decl => res.add(decl); res })
        @Expect(decls[0].initializer.isNone())
        @Expect(decls[1].initializer.isSome())
        @Expect(decls[2].initializer.isNone())
        @Expect(decls[3].initializer.isSome())
    }


    @TestCase
    func binaryExpr_test() {
        let test: String = """
            main(){
                1 + 5
                1 - 5
                1 * 5
                1 / 5
                1 ** 5
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is BinaryExpr }))
    }


    @TestCase
    func unaryExpr_test() {
        let test: String = """
            main(){
                -134
                !134
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is UnaryExpr }))
    }

    @TestCase
    func parenExpr_test() {
        let test: String = """
            main(){
                (-134)
                (134 + (5486 - 12) + a)
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is ParenExpr }))
    }

    @TestCase
    func litConstExpr_test() {
        let test: String = """
            main(){
                1231
                "string"
                ()
                1.2
                true
                false
                r'a'
                b'1'
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is LitConstExpr }))
    }

    @TestCase
    func assignExpr_test() {
        let test: String = """
            main(){
                a = 1231 + 8735
                b = a
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is AssignExpr }))
    }

    @TestCase
    func refExpr_test() {
        let test: String = """
            main(){
                identifier
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is RefExpr }))
    }

    @TestCase
    func ifExpr_test() {
        let test: String = """
            main(){
                if (expression) {
                    expression
                } else if (expression) {
                    expression
                } else {
                    expression
                }
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is IfExpr }))
    }

    @TestCase
    func ifExprDesugar_test() {
        let test: String = """
            main(){
                if (expression) {
                    expression
                }
            }"""
        // Should add the else branch while parsing.
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is IfExpr }))
    }

    @TestCase
    func whileExpr_test() {
        let test: String = """
            main(){
                while (expression) {
                    expression
                }
            }"""
        // Should add the else branch while parsing.
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is WhileExpr }))
    }

    @TestCase
    func callExpr_test() {
        let test: String = """
            main(){
                a()
            }"""
        // Should add the else branch while parsing.
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is CallExpr }))
    }

    @TestCase
    func returnExpr_test() {
        let test: String = """
            main(){
                return expression
            }"""
        // Should add the else branch while parsing.
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is ReturnExpr }))
    }

    // The following tests will be added after the change to the return expression.
    @TestCase
    func returnExprNoExpression_test() {
        let test: String = """
            main(){
                return
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is ReturnExpr }))
    }

    @TestCase
    func returnExprUnitFunc_test() {
        let test: String = """
            main(): Unit{
                return a
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is ReturnExpr }))
    }

    @TestCase
    func jumpExpr_test() {
        let test: String = """
            main(){
                break
                continue
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is JumpExpr }))
    }

    @TestCase
    func memberAccess_test() {
        let test: String = """
            main(){
                a.b.c().f
                c().b
                Int64(a).c
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is MemberAccess }))
    }

    @TestCase
    func primitiveTypeExpr_test() {
        let test: String = """
            main(){
                Int64
                Unit
            }"""
        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is PrimitiveTypeExpr }))
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


