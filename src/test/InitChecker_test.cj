package cjcj.test

import cjcj.asg.typeChecker.TypeChecker
import cjcj.asg.AsgMaker
import cjcj.asg.initChecker.*
import cjcj.visitor.Program
import cjcj.parser
import cjcj.scanner.*

import std.env.*
import std.collection.ArrayList

@Test
class InitCheckerTests {
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
    
    // private func getAsg(test: String): Program {
    //     let asg = AsgMaker().resolve(getAst(test))
    //     TypeChecker(asg)
    //     asg
    // }

    private func resolve(test: String) {
        let asg = AsgMaker().resolve(getAst(test))

        InitChecker(TypeChecker(asg).classEnvironment).resolve(asg)
    }

    @TestCase 
    func variableReference_test() {
        let testWrong: String = """
            main() {
                let a: Int64
                let b = a
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main() {
                let a: Int64 = 1
                let b = a
            }
        """

        resolve(testRight)
       resolve(testRight)
    }

    @TestCase 
    func ifelseInitialization_test() {
        let testWrong: String = """
            main() {
                let a: Int64
                if (true) {
                    a = 1
                }                
                let b = a
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main() {
                let a: Int64
                if (true) {
                    a = 1
                } else {
                    a = 3
                }
                
                let b = a
            }
        """

       resolve(testRight)
    }


    @TestCase 
    func ifelseInitializationComplex_test() {
        var testWrong: String = """
            main() {
                let a: Int64
                if (true) {
                    a = 1
                } else if (true) {
                    a = 2
                } else {
                }
                
                let b = a
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        testWrong = """
            main() {
                let a: Int64
                while (true) {
                    if (true) {
                        a = 1
                    } else {
                        a = 2
                    }
                }
                
                let b = a
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main() {
                let a: Int64
                if (true) {
                    a = 1
                } else if (true) {
                    a = 2
                } else {
                    a = 3
                }
                
                let b = a
            }
        """

       resolve(testRight)
    }


    @TestCase
    func ifelseInitializationComplex2_test() {
        let testWrong: String = """
            main () {
                let A: Int32

                if(true) {
                    A = 3
                } else {
                    if(true) {
                        A = 5
                    } else {
                    }
                }

                if(true) {
                } else {
                    A = 4
                }

                let B = A
                A = 1
            }

            """

        @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main () {
                let A: Int64

                if(true) {
                    A = 3
                } else {
                    if(true) {
                        A = 5
                    } else {
                    }
                }

                if(true) {
                } else {
                    A = 4
                }

                A = 1
            }
            """

        resolve(testRight)
    }

    @TestCase 
    func blockInitialization_test() {
        let testWrong: String = """
            main() {
                let a: Int64
                while(true){
                    a = 1
                }
                
                let b = a
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main() {
                let a: Int64
                while(true){
                    a = 1
                }
                a = 2
                
                let b = a
            }
        """

       resolve(testRight)
    }

    @TestCase 
    func declarationInitialization_test() {
        let testRight: String = """
            main() {
                let a: Int64 = 1
                let b = a
            }
        """

       resolve(testRight)
    }



    @TestCase 
    func mutation_test() {
        let testWrong: String = """
            main() {
                let a: Int64 = 1
                a = 2
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main() {
                var a: Int64 = 1
                a = 2
            }
        """

       resolve(testRight)
    }

    @TestCase
    func mutationComplex_test() {
        let testWrong: String = """
            main() {
                let a: Int64 = 1
                if (true) {
                    a = 2
                }
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main() {
                var a: Int64 = 1
                if (true) {
                    a = 2
                }
            }
        """

       resolve(testRight)
    }


    @TestCase
    func mutationComplex2_test() {
        let testWrong: String = """
            main () {
                let A: Int64

                if(true) {
                    A = 3
                } else {
                    A = 1
                    if(true) {
                    } else {
                        A = 2
                    }
                }
            }
            """

        @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main () {
                var A: Int64

                if(true) {
                    A = 3
                } else {
                    A = 1
                    if(true) {
                    } else {
                        A = 2
                    }
                }
            }
            """

        resolve(testRight)
    }

    @TestCase
    func initializationInsideFunctions_test() {
        let testWrong: String = """
            main() {
                let a: Int64
                func F() {
                    a = 2
                }
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main() {
                var a: Int64 = 1
                func F() {
                    a = 2
                }
            }
        """

       resolve(testRight)
    }

    @TestCase
    func initializationOfParameters_test(){
        let testWrong: String = """
            main() {
                func a(b: String, c: Int64) : Int64 {
                    c = 1
                    c
                }
                a("1", 2)
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            main() {
                func a(b: String, c: Int64) : Int64 {
                    c
                }
                a("1", 2)
            }
        """

       resolve(testRight)

    }


    @TestCase
    func classInit_test() {
        let testWrong: String = """
            class C{
                let a: Int64
                init() {
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            class C{
                let a: Int64
                init() {
                    a = 1
                }
            }
            main() {
            }
        """

       resolve(testRight)
    }


    @TestCase
    func classInitMultiVar_test() {
        let testWrong: String = """
            class C{
                let a: Int64 = 1
                let b: Int64
                init() {
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            class C{
                let a: Int64 = 1
                let b: Int64
                init() {
                    b = 2
                }
            }
            main() {
            }
        """

       resolve(testRight)
    }

    @TestCase
    func classInitFunctionCall_test() {
        let testWrong: String = """
            class C{
                let b: Int64
                init() {
                    F()
                    b = 2
                }

                func F() {
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            class C{
                let b: Int64
                init() {
                    b = 2
                    F()
                }

                func F() {
                }
            }
            main() {
            }
        """

       resolve(testRight)
    }


    @TestCase
    func classInitFunctionCallinVarDecl_test() {
        let testWrong: String = """
            class C{
                let b: Int64 = F()
                init() {
                }

                func F() {
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](resolve(testWrong))
    }


    @TestCase
    func classInitMutation_test() {
        let testWrong: String = """
            class C{
                let b: Int64 = 1
                init() {
                    b = 2
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            class C{
                var b: Int64 = 1
                init() {
                    b = 2
                }
            }
            main() {
            }
        """

       resolve(testRight)
    }


    @TestCase
    func classInitMutationComplex_test() {
        let testWrong: String = """
            class C{
                let b: Int64 = 1
                init() {
                }

                func F() {
                    b = 2
                }
            }
            main() {
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            class C{
                var b: Int64 = 1
                init() {
                }

                func F() {
                    b = 2
                }
            }
            main() {
            }
        """

       resolve(testRight)
    }

    @TestCase
    func classReferenceBeforeInitialization_test() {
        let testWrong: String = """
            func External(a: CLASS) {
                a
            }

            class CLASS{
                let a: Int64
                init() {
                    External(this)
                    a = 1
                }
            }
            main(){
            }
        """
       @AssertThrows[Exception](resolve(testWrong))

        let testRight: String = """
            func External(a: CLASS) {
                a
            }

            class CLASS{
                let a: Int64
                init() {
                    a = 1
                    External(this)
                }
            }
            main(){
            }
        """

       resolve(testRight)
    }

    @TestCase
    func classInitSuperFunctionCall_test() {
        let testWrong: String = """
            class SCLASS {
                func g(){
                }
            }

            class CLASS <: SCLASS{
                let a: Int64
                init() {
                    g()
                    a = 1
                }
            }
            main(){
            }
        """
       @AssertThrows[Exception](resolve(testWrong))
    }

    @TestCase
    func classInitSuperMemberAccess_test() {
        let testRight: String = """
            class SCLASS {
                var a: Int64

                init() {
                    a = 1
                }
            }

            class CLASS <: SCLASS {
                init() {
                    this.a = 1
                    super.a = 1
                    a = 1
                }
            }
            main(){
            }
        """
       resolve(testRight)

        let testWrong: String = """
            class SCLASS {
                let a: Int64

                init() {
                    a = 1
                }
            }

            class CLASS <: SCLASS {
                init() {
                    super.a = 1
                }
            }
            main(){
            }
        """
       @AssertThrows[Exception](resolve(testWrong))
    }

    @TestCase
    func classInitMemberAccess_test() {
        let testRight: String = """
            class CLASS {
                let a: Int64

                init() {
                    if(true) {
                        a = 2
                    }

                    a = 1
                }
            }
            main(){
            }
        """
        resolve(testRight)

        let testWrong: String = """
            class CLASS {
                let a: Int64

                init() {
                    if(true) {
                        a = 2
                    } else {
                        f()
                    }

                    a = 1
                }
                func f() {
                }
            }
            main(){
            }
        """
       @AssertThrows[Exception](resolve(testWrong))
    }

    
    @TestCase
    func globalVarUseBeforeInitialization_test(){
        let testRight: String = """
            let var1 = CLASS2().F()
            var var2 = 1

            class CLASS2{
                func F(){
                    var2 = 1
                }
            }

            main(){
            }
        """
        resolve(testRight)

        let testWrong: String = """
            let var1 = CLASS2().F()
            var var2 = 1

            class CLASS2{
                func F(){
                    let x = var2
                }
            }

            main(){
            }
        """
        @AssertThrows[Exception](resolve(testWrong))

        let testWrongHard: String = """
            class CLASS {
                let a = 1
            }
            let var1 = CLASS2().F()
            var var2 = CLASS()

            class CLASS2{
                func F(){
                    let x = var2.a
                }
            }

            main(){
            }
        """
        @AssertThrows[Exception](resolve(testWrongHard))
    }

    @TestCase
    func instanceMemberAccess_test(){
        let testRight: String = """
            class C{
                var b: Int64 = 1
            }
            main(){
                let a = C()

                let b = a.b
                a.b = 1
            }
        """
        resolve(testRight)

        let testWrong: String = """
            class C{
                var b: Int64 = 1
            }
            main(){
                let a: C

                let b = a.b
            }
        """
        @AssertThrows[Exception](resolve(testWrong))

        let testWrong2: String = """
            class C{
                var b: Int64 = 1
            }
            main(){
                let a: C

                a.b = 1
            }
        """
        @AssertThrows[Exception](resolve(testWrong2))
    }

    @TestCase
    func instanceThisDifferece_test(){
        let testRight: String = """
            class C{
                var b: Int64

                init() {
                    b = 1
                }

                init(v: Int64) {
                    let c = C().b
                    b = 2
                }
            }
            main() {
            }
        """
        resolve(testRight)

        let testRightFunctionCase: String = """
            class C{
                var b: Int64

                init() {
                    b = 1
                }

                init(v: Int64) {
                    C().f()
                    b = 2
                }

                func f() {
                }
            }
            main() {
            }
        """
        resolve(testRightFunctionCase)
        
        let testWrong: String = """
            class C{
                var b: Int64

                init(v: Int64) {
                    this.f()
                    b = 2
                }

                func f() {
                }
            }
            main() {
            }
        """

        @AssertThrows[Exception](resolve(testWrong))
    }
    
}
