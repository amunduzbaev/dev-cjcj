package cjcj.test

import cjcj.asg.AsgMaker
import cjcj.visitor.*
import cjcj.parser
import cjcj.scanner.*
import cjcj.prettyPrinter.PrettyPrinter

import std.env.*
import std.collection.ArrayList

@Test
class AsgMakerTests {
    private func scan(test: String): Array<Token> {
        Scanner(test.toRuneArray()).scanTokens().toArray()  
    }

    private func parse(test: String): ?Program {
        let tokens: Array<Token> = scan(test)
        parser.Parser(tokens, parser.Reporter(getStdErr(), tokens)).parse()
    }

    private func getAst(test: String): Program {
        let program = parse(test)
        if (let Some(p) <- program) {
            return p
        }
        @Fail("Couldn't parse the program")
    }
    
    private func getAsg(test: String): Program {
        AsgMaker().resolve(getAst(test))
    }

    private func getMain(test: String): MainDeclWithRef {
        let asg = getAsg(test)
        for (d in asg.decls) {
            if (let Some(m) <- (d as MainDeclWithRef)) {
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
    func funcDecl_test() {
        let test: String = """
            main(){
                func a() {
                }
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDeclWithRef }))
    }

    @TestCase
    func funcDeclParams_test() {
        let test: String = """
            class CustomType {
            }
            main(){
                func a(a: Int64, b: Unit, c: CustomType) {
                }
            }
            """

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDeclWithRef }))
        let decl: FuncDeclWithRef = (m.block.nodes[0] as FuncDeclWithRef).getOrThrow()
        @Assert(decl.params.size == 3)
    }

    @TestCase
    func funcDeclDeclType_test() {
        let test: String = """
            main(){
                func a(): Int64 {
                }
            }
            """

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDeclWithRef }))
        let decl: FuncDeclWithRef = (m.block.nodes[0] as FuncDeclWithRef).getOrThrow()
        @Assert(decl.declType.isSome())
    }

    @TestCase
    func funcDeclBlock_test() {
        let test: String = """
            func f() {
            }
            main(){
                func a() {
                    let test = 3986
                    var b: String = "string"
                    while (test == 5) {
                        f()
                    }
                    if (true) {
                        return 9
                    }
                    return 6347
                }
            }
            """

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDeclWithRef }))
        let decl: FuncDeclWithRef = (m.block.nodes[0] as FuncDeclWithRef).getOrThrow()
        @Assert(decl.block.nodes.size == 5)
    }

    @TestCase
    func funcDeclGeneral_test() {
        let test: String = """
            class CustomType {
            }
            main(){
                func a(a: Int64, b: Unit, c: CustomType): Int64 {
                    let bo = 5
                    if (bo == 7) {
                        return 4
                    }
                    return 10
                }
            }"""

        let m: MainDecl = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is FuncDeclWithRef }))
        let decl: FuncDeclWithRef = (m.block.nodes[0] as FuncDeclWithRef).getOrThrow()
        @Assert(decl.declType.isSome())
        @Assert(decl.params.size == 3)
        @Assert(decl.block.nodes.size == 6)
        // block has 6 nodes, because it adds declaration of variables a, b, c as 3 new nodes
    }

    @TestCase
    func classDecl_test() {
        let test: String = """
            class a {
            }
            main(){
            }"""

        let program = getAsg(test)
        @Assert(program.decls[0] is ClassDeclWithRef)
    }

    @TestCase
    func classDeclWithSupertypes_test() {
        let test: String = """
            class a <: b & c & d {
            }
            class b {
            }
            class c {
            }
            class d {
            }
            main(){
            }"""

        let program = getAsg(test)
        @Assert(program.decls[0] is ClassDeclWithRef)
        let classDecl = (program.decls[0] as ClassDeclWithRef).getOrThrow()
        @Assert(classDecl.superTypes.size == 3)
    }

    @TestCase
    func classDeclBody_test() {
        let test: String = """
            class a {
                let a = 6
                let b: Int64 = 347
                func c() {
                }
                init(a: CustomType) {
                }
            }
            class CustomType {
            }
            main(){
            }"""

        let program = getAsg(test)
        @Assert(program.decls[0] is ClassDeclWithRef)
        let classDecl = (program.decls[0] as ClassDeclWithRef).getOrThrow()
        @Assert(classDecl.body.decls.size == 4)
    }

    @TestCase
    func varDecl_test() {
        let test: String = """
            main(){
                let a: Int32
                let b: Int64 = 567
                var c: Int32
                var d = 567
            }"""

        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is VarDeclWithRef }))
        let decls: ArrayList<VarDeclWithRef> = m.block.nodes.iterator()
            .map({ n => (n as VarDeclWithRef).getOrThrow() })
            .fold(ArrayList(), { res, decl => res.add(decl); res })
        @Expect(decls[0].initializer.isNone())
        @Expect(decls[1].initializer.isSome())
        @Expect(decls[2].initializer.isNone())
        @Expect(decls[3].initializer.isSome())

        @Expect(decls[0].declType.isSome())
        @Expect(decls[1].declType.isSome())
        @Expect(decls[2].declType.isSome())
        @Expect(decls[3].declType.isNone())

        @Expect(decls[0].keyword.kind == TokenKind.LET)
        @Expect(decls[1].keyword.kind == TokenKind.LET)
        @Expect(decls[2].keyword.kind == TokenKind.VAR)
        @Expect(decls[3].keyword.kind == TokenKind.VAR)
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

        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is BinaryExpr }))
    }

    @TestCase
    func unaryExpr_test() {
        let test: String = """
            main(){
                -134
                !134
            }"""

        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is UnaryExpr }))
    }

    @TestCase
    func parenExpr_test() {
        let test: String = """
            let a = 2
            main(){
                (-134)
                (134 + (5486 - 12) + a)
            }"""
        let m: MainDeclWithRef = getMain(test)
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
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is LitConstExpr }))
    }

    @TestCase
    func assignExpr_test() {
        let test: String = """
            var a: Int64 = 1
            var b: Int64 = 2
            main(){
                a = 1231 + 8735
                b = a
            }"""
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is AssignExpr }))
    }

    @TestCase 
    func variableReference() {
        let testWrong: String = """
            main(){
                let b = a
            }
        """
        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))

        let testRight: String = """
            main(){
                let a = 5
                let b = a
            }
        """

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func functionReference() {
        let testWrong: String = """
            main(){
                let b = f(1, 2)
            }
        """
        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))

        let testRight: String = """
            main(){
                func f(a: Int64, b: Int64) {
                    a
                }
                let b = f(1, 2)
            }
        """
        
        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func recursiveFunction() {
        let testWrong: String = """
            main(){
                func f() {
                    g()
                    1
                }
            }
        """
        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))

        let testRight: String = """
            main(){
                func f() {
                    f()
                    1
                }
            }
        """

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func unorderedDeclarations() {
        let testWrong: String = """
            func f(){
                a
            }
            let a = 5
            main(){
            }
        """
        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))

        var testRight: String = """
            let a = f()
            func f(){
                5
            }
            main(){
            }
        """

        AsgMaker().resolve(getAst(testRight))

        testRight = """
            func g() {
                f()
            }
            func f(){
                g()
                5
            }
            main(){
            }
        """

        AsgMaker().resolve(getAst(testRight))

        testRight = """
            func g() {
                C()
            }

            class C{
            }
            main(){
            }
        """

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func selfInitClass() {
        var testRight: String = """
            class D{
                func F() {
                    let c = D()
                    1
                }
            }
            main(){
            }
        """

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase 
    func unorderedClassDeclaration() {
        var testRight: String = """
            class B <: A{
            }
            class A {
            }
            main(){
            }
        """

        AsgMaker().resolve(getAst(testRight))

        // var testWrong: String = """
        //     class A {
        //     }
        //     main(){
        //         class B <: A{
        //         }
        //     }
        // """

        // @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))
    }

    @TestCase
    func referenceReuse() {
        var testRight: String = """
        func f() {
            func h() {
                g()
            }

            h()
        }

        func g(){
            1
        }

        main(){
        }
        """

        AsgMaker().resolve(getAst(testRight))
    }

    @TestCase
    func builtinTypes() {
        var testRight: String = """
        main() {
            func a(b: String, c: Any): Int64 {
                1
            }

            a("2", 1)
        }
        """

        AsgMaker().resolve(getAst(testRight))

        var testWrong: String = """
        main() {
            func a(b: UndeclaredType): Int64 {
                1
            }

            a("String")
        }
        """

        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))
    }

    @TestCase
    func customTypes() {
        var testRight: String = """
        class T{
        }

        func f(a: T, b: K): Int64{
            1
        }

        class K{
        }

        main() {
            f(T(), K())
        }
        """

        AsgMaker().resolve(getAst(testRight))

        var testWrong: String = """
        class T{
        }

        func f(a: T, b: K): Int64{
            1
        }

        main() {
            f(T(), K())
        }
        """
        @AssertThrows[Exception](AsgMaker().resolve(getAst(testWrong)))
    }

    @TestCase
    func memberAccess_test() {
        let testRight: String = """
            class a {
                let b: Int64
            }
            main(){
                let b = a()
                let c: Int64 = b.b
            }"""
        AsgMaker().resolve(getAst(testRight))
        let testWrong: String = """
            class a {
                let b: Int64
            }
            main(){
                let b = a()
                let c: String = b.b
            }"""
        AsgMaker().resolve(getAst(testWrong))
    }

    @TestCase
    func asgMakerTest1() {
        let test: String = """
            main(args: Int64) {
                func aa(b: Int64, h: Int32): Int64 {
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
        AsgMaker().resolve(getAst(test))
    }

    @TestCase
    func asgMakerTest2() {
        let test: String = """
            class Type{
            }
            
            main(args: Int32){
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
                let c = a - a

                a = 3
                a = 5.2
                a = (a * c + (b - c)) ** 3

                A()
                A(1, 2, "test-param")
            }
            /*
                Some comment
                3(*&#@71I#(@))))))
            */
            """
        AsgMaker().resolve(getAst(test))
    }
}


