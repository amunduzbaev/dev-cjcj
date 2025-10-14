package cjcj.test

import cjcj.asg.AsgMaker
import cjcj.visitor.*
import cjcj.parser
import cjcj.scanner.*

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
        @Assert(decl.block.getOrThrow().nodes.size == 5)
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
        @Assert(decl.block.getOrThrow().nodes.size == 3)
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
    func classDeclFuncConflict_test() {
        let test: String = """
            class a {
            }
            func a() {
            }
            main(){
            }"""
        @AssertThrows[Exception](getAsg(test))
    }

    @TestCase
    func classDeclVarConflict_test() {
        let test: String = """
            class a {
            }
            let a = 5
            main(){
            }"""
        @AssertThrows[Exception](getAsg(test))
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
    func refExpr_test() {
        let test: String = """
            let identifier = 1
            main(){
                identifier
            }"""
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is RefExprWithRef }))
    }

    @TestCase
    func ifExpr_test() {
        let test: String = """
            main(){
                if (1 == 2) {
                    1
                } else if (1 == 3) {
                    2
                } else {
                    3
                }
            }"""
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is IfExpr }))
    }

    @TestCase
    func ifExprDesugar_test() {
        let test: String = """
            main(){
                if (1 == 2) {
                    1
                }
            }"""
        // Should add the else branch while parsing.
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is IfExpr }))
    }

    @TestCase
    func whileExpr_test() {
        let test: String = """
            main(){
                while (1 == 2) {
                    1
                }
            }"""
        // Should add the else branch while parsing.
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is WhileExpr }))
    }

    @TestCase
    func callExpr_test() {
        let test: String = """
            func a() {
            }
            main(){
                a()
            }"""
        // Should add the else branch while parsing.
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is CallExpr }))
    }

    @TestCase
    func returnExpr_test() {
        let test: String = """
            main(){
                return 1
            }"""
        // Should add the else branch while parsing.
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is ReturnExpr }))
    }

    @TestCase
    func returnExprNoExpression_test() {
        let test: String = """
            main(){
                return
            }"""
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is ReturnExpr }))
    }

    @TestCase
    func returnExprUnitFunc_test() {
        let test: String = """
            let a = 1
            main(): Unit{
                return a
            }"""
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is ReturnExpr }))
    }


    @TestCase
    func jumpExpr_test() {
        let test: String = """
            main(){
                break
                continue
            }"""
        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is JumpExpr }))
    }

    // @TestCase
    // func primitiveTypeExpr_test() {
    //     let test: String = """
    //         main(){
    //             Int64
    //             Unit
    //         }"""
    //     let m: MainDeclWithRef = getMain(test)
    //     @Assert(m.block.nodes.iterator().all({ n => n is PrimitiveTypeExpr }))
    // }

    @TestCase
    func memberAccess_test() {
        let test: String = """
            class B {
                let f = 1
                func c() {
                    B()
                }
            }
            class A {
                let b: B = B()
            }
            let a: A = A()
            func c() {
                A()
            }
            main(){
                a.b.c().f
                c().b
            }
            """

        let m: MainDeclWithRef = getMain(test)
        @Assert(m.block.nodes.iterator().all({ n => n is MemberAccess }))
    }

    @TestCase 
    func variableReference_test() {
        let testWrong: String = """
            main(){
                let b = a
            }
        """
        @AssertThrows[Exception](getAsg(testWrong))

        let testRight: String = """
            main(){
                let a = 5
                let b = a
            }
        """

        getAsg(testRight)
    }

    @TestCase 
    func functionReference_test() {
        let testWrong: String = """
            main(){
                let b = f(1, 2)
            }
        """
        @AssertThrows[Exception](getAsg(testWrong))

        let testRight: String = """
            main(){
                func f(a: Int64, b: Int64) {
                    a
                }
                let b = f(1, 2)
            }
        """
        
        getAsg(testRight)
    }

    @TestCase 
    func recursiveFunction_test() {
        let testWrong: String = """
            main(){
                func f() {
                    g()
                    1
                }
            }
        """
        @AssertThrows[Exception](getAsg(testWrong))

        let testRight: String = """
            main(){
                func f() {
                    f()
                    1
                }
            }
        """

        getAsg(testRight)
    }

    @TestCase 
    func unorderedDeclarations_test() {
        var testRight: String = """
            let a = f()
            func f(){
                5
            }
            main(){
            }
        """

        getAsg(testRight)

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

        getAsg(testRight)

        testRight = """
            func g() {
                C()
            }

            class C{
            }
            main(){
            }
        """

        getAsg(testRight)
    }

    @TestCase 
    func selfInitClass_test() {
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

        getAsg(testRight)
    }

    @TestCase 
    func unorderedClassDeclaration_test() {
        var testRight: String = """
            class B <: A{
            }
            class A {
            }
            main(){
            }
        """

        getAsg(testRight)
    }

    @TestCase
    func referenceReuse_test() {
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

        getAsg(testRight)
    }

    @TestCase
    func builtinTypes_test() {
        var testRight: String = """
        main() {
            func a(b: String, c: Any): Int64 {
                1
            }

            a("2", 1)
        }
        """

        getAsg(testRight)

        var testWrong: String = """
        main() {
            func a(b: UndeclaredType): Int64 {
                1
            }

            a("String")
        }
        """

        @AssertThrows[Exception](getAsg(testWrong))
    }

    @TestCase
    func customTypes_test() {
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

        getAsg(testRight)

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
        @AssertThrows[Exception](getAsg(testWrong))
    }

    @TestCase
    func thisSuperExpression_test() {
        var testRight: String = """
        class T{
            let a = this
        }
        main() {
        }
        """
        getAsg(testRight)

        var testWrong: String = """
        main() {
            this
        }
        """
        @AssertThrows[Exception](getAsg(testWrong))
    }

    @TestCase
    func declaratorFactory_test() {
        var testWrong: String = """
        func f() {
        }

        class f {
        }

        main(){
        }
        """

        @AssertThrows[Exception](getAsg(testWrong))
    }

    @TestCase 
    func interfaceDeclaration_test() {
        var testRight: String = """
        interface I {
            func f(a: Int64): Unit
            func sum(a: Int64, b: Int64): Int64 {
                a + b
            }
        }

        main() {
        }
        """

        getAsg(testRight)

        var testWrong: String = """
        func g(a: Int64): Unit 
        main() {
        }
        """

        @AssertThrows[Exception](getAsg(testWrong))
    }

    @TestCase 
    func interfaceDeclarationComplex_test() {
        var testRight: String = """
        let c: Int64 = 1
        interface I {
            func sum(a: Int64, b: Int64): Int64 {
                a + b + c
            }
            func max_(a: Int64, b: Int64): Int64 {
                if(a > b && a > c) {
                    a
                } else if(b > c) {
                    b
                } else {
                    c
                }
            }
        }
        main() {
        }
        """

        getAsg(testRight)

        var testWrong: String = """
        interface I {
            func f() {
                func g(b: Int64): Unit
                1
            }
        }
        main() {
        }
        """

        @AssertThrows[Exception](getAsg(testWrong))
    }

    @TestCase 
    func interfaceInstance_test() {
        var testWrong: String = """
        interface I {
            func f() {
                1
            }
        }
        main() {
            let a = I()
        }
        """

        @AssertThrows[Exception](getAsg(testWrong))

        var testRight: String = """
        interface I { }
        class C <: I { }
        main() {
            let c: I = C()
        }
        """

        getAsg(testRight)
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
        getAsg(test)
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
        getAsg(test)
    }
}


// interface I {
//     func f(): Int64
// }

// interface J {
//     func f(): Int64
// }

// class C <: I & J {

// }

// let var2 = 1

// interface I {
//     func f() {
//         1
//     }
// }

// class C <: S & I {
//     init() {
//         // let var2 = 1
//         let c = var2
//         let d = f()
//     }

//     override public func f() {
//         1
//     }
// }

// open class S {
//     let var2 = "test"
// }

// func f(a: Int64): Int64 { 1 }
// func f(a: Hashable): Int64 { 1 }

// let a = f
