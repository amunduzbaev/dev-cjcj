package cjcj.scanner


import std.deriving.*

@Derive[ToString, Equatable]
public enum TokenKind {
        DOT
    | /*  "."           */
        COMMA
    | /*  ","           */
        LPAREN
    | /*  "("           */
        RPAREN
    | /*  ")"           */
        LSQUARE
    | /*  "["           */
        RSQUARE
    | /*  "]"           */
        LCURL
    | /*  "{"           */
        RCURL
    | /*  "}"           */
        EXP
    | /*  "**"          */
        MUL
    | /*  "*"           */
        MOD
    | /*  "%"           */
        DIV
    | /*  "/"           */
        ADD
    | /*  "+"           */
        SUB
    | /*  "-"           */
        INCR
    | /*  "++"          */
        DECR
    | /*  "--"          */
        AND
    | /*  "&&"          */
        OR
    | /*  "||"          */
        NOT
    | /*  "!"           */
        BITAND
    | /*  "&"           */
        BITOR
    | /*  "|"           */
        BITXOR
    | /*  "^"           */
        BITNOT
    | /*  "~"           */
        LSHIFT
    | /*  "<<"          */
        RSHIFT
    | /*  ">>"          */
        COLON
    | /*  ":"           */
        SEMI
    | /*  ";"           */
        ASSIGN
    | /*  "="           */
        ADD_ASSIGN
    | /*  "+="          */
        SUB_ASSIGN
    | /*  "-="          */
        MUL_ASSIGN
    | /*  "*="          */
        DIV_ASSIGN
    | /*  "/="          */
        MOD_ASSIGN
    | /*  "%="          */
        BACKARROW
    | /*  "<-"          */
        DOUBLE_ARROW
    | /*  "=>"          */
        HASH
    | /*  "#"           */
        QUEST
    | /*  "?"           */
        LT
    | /*  "<"           */
        GT
    | /*  ">"           */
        LE
    | /*  "<="          */
        GE
    | /*  ">="          */
        IS
    | /*  "is"          */
        AS
    | /*  "as"          */
        NOTEQ
    | /*  "!="          */
        EQUAL
    | /*  "=="          */
        WILDCARD
    | /*  "_"           */
        INT8
    | /*  "Int8"        */
        INT16
    | /*  "Int16"       */
        INT32
    | /*  "Int32"       */
        INT64
    | /*  "Int64"       */
        INTNATIVE
    | /*  "IntNative"   */
        UINT8
    | /*  "UInt8"       */
        UINT16
    | /*  "UInt16"      */
        UINT32
    | /*  "UInt32"      */
        UINT64
    | /*  "UInt64"      */
        UINTNATIVE
    | /*  "UIntNative"  */
        FLOAT16
    | /*  "Float16"     */
        FLOAT32
    | /*  "Float32"     */
        FLOAT64
    | /*  "Float64"     */
        RUNE
    | /*  "Rune"        */
        BOOLEAN
    | /*  "Bool"        */
        NOTHING
    | /*  "Nothing"     */
        UNIT
    | /*  "Unit"        */
        STRUCT
    | /*  "struct"      */
        ENUM
    | /*  "enum"        */
        VARRAY
    | /*  "VArray"      */
        THISTYPE
    | /*  "This"        */
        CLASS
    | /*  "class"       */
        FUNC
    | /*  "func"        */
        LET
    | /*  "let"         */
        VAR
    | /*  "var"         */
        CONST
    | /*  "const"       */
        TYPE
    | /*  "type"        */
        INIT
    | /*  "init"        */
        THIS
    | /*  "this"        */
        SUPER
    | /*  "super"       */
        IF
    | /*  "if"          */
        ELSE
    | /*  "else"        */
        DO
    | /*  "do"          */
        WHILE
    | /*  "while"       */
        RETURN
    | /*  "return"      */
        CONTINUE
    | /*  "continue"    */
        BREAK
    | /*  "break"       */
        MATCH
    | /*  "match"       */ 
        PROP
    | /*  "prop"        */
        STATIC
    | /*  "static"      */
        PUBLIC
    | /*  "public"      */
        PRIVATE
    | /*  "private"     */
        INTERNAL
    | /*  "internal"     */
        PROTECTED
    | /*  "protected"   */
        OVERRIDE
    | /*  "override"    */
        ABSTRACT
    | /*  "abstract"    */
        SEALED
    | /*  "sealed"      */
        OPEN
    | /*  "open"        */
        INOUT
    | /*  "inout"       */
        MUT
    | /*  "mut"         */
        OPERATOR
    | /*  "operator"    */
        UPPERBOUND
    | /*  "<:"          */
        MAIN
    | /*  "main"        */
        IDENTIFIER
    | /*  "x"           */
        INTEGER_LITERAL
    | /*  e.g. "1"      */
        RUNE_BYTE_LITERAL
    | /*  e.g. "b'x'"   */
        FLOAT_LITERAL
    | /*  e.g. "'1.0'"  */
        COMMENT
    | /*  e.g. "/*xx*/" */
        NL
    | /*  newline         */
        END
    | /*  end of file     */
        RUNE_LITERAL
    | /*  e.g. "r'x'"       */
        STRING_LITERAL
    | /*  e.g. ""xx""     */


    //     SINGLE_QUOTED_STRING_LITERAL
    // | /*  e.g. "'xx'"     */
    //     MULTILINE_STRING
    // | /*  e.g. """"aaa""""   */
    //     MULTILINE_RAW_STRING
    // | /*  e.g. "#"aaa"#"     */


        BOOL_LITERAL
    | /*  "true" or "false"  */
        UNIT_LITERAL
      /*  "()"               */
    | ILLEGAL

}

public class TokenKindHelper {
    public static let PRIMITIVE_TYPE_TOKEN_KIND: Array<TokenKind> = [
        INT8, 
        INT16,
        INT32,
        INT64,
        INTNATIVE,
        UINT8,
        UINT16,
        UINT32,
        UINT64,
        UINTNATIVE,
        FLOAT16,
        FLOAT32,
        FLOAT64,
        RUNE,
        BOOLEAN,
        NOTHING,
        UNIT
    ]

    public static let MODIFIERS_TOKEN_KIND: Array<TokenKind> = [
        PROP,
        STATIC,
        PUBLIC,
        PRIVATE,
        INTERNAL,
        PROTECTED,
        OVERRIDE,
        ABSTRACT,
        SEALED,
        OPEN,
        INOUT,
        MUT,
        CONST
    ]

    public static let CLASS_MODIFIERS_TOKEN_KIND: Array<TokenKind> = [
        PUBLIC,
        PRIVATE,
        INTERNAL,
        PROTECTED,
        ABSTRACT,
        OPEN
    ]

    public static let FUNCTION_MODIFIERS_TOKEN_KIND: Array<TokenKind> = [
        PUBLIC,
        PRIVATE,
        PROTECTED,
        INTERNAL,
        STATIC,
        OPEN,
        MUT,
        CONST
    ]

    public static let VAR_MODIFIERS_TOKEN_KIND: Array<TokenKind> = [
        PUBLIC,
        PRIVATE,
        PROTECTED,
        INTERNAL,
        STATIC
    ]

    public static let STRUCT_MODIFIERS_TOKEN_KIND: Array<TokenKind> = [
        PUBLIC,
        PRIVATE,
        PROTECTED,
        INTERNAL
    ]

    
    

    public static let ASSIGNMENT_OPERATOR: Array<TokenKind> = [
        TokenKind.ASSIGN
    ]

    public static let COMPARISON_OPERATOR: Array<TokenKind> = [
        TokenKind.LT,
        TokenKind.GT,
        TokenKind.LE,
        TokenKind.GE
    ]

    public static let EQUALITY_OPERATOR: Array<TokenKind> = [
        TokenKind.NOTEQ,
        TokenKind.EQUAL
    ]

    public static let ADDITIVE_OPERATOR: Array<TokenKind> = [
        TokenKind.ADD,
        TokenKind.SUB
    ]

    public static let EXPONENT_OPERATOR: Array<TokenKind> = [
        TokenKind.EXP
    ]

    public static let MULTIPLICATIVE_OPERATOR: Array<TokenKind> = [
        TokenKind.MOD,
        TokenKind.DIV,
        TokenKind.MUL
    ]

    public static let PREFIX_UNARY_OPERATOR: Array<TokenKind> = [
        TokenKind.SUB,
        TokenKind.NOT
    ]

    public static let THIS_SUPER: Array<TokenKind> = [
        TokenKind.THIS,
        TokenKind.SUPER
    ]

    public static let NUMERIC_TYPES: Array<TokenKind> = [
        TokenKind.INT8,
        TokenKind.INT16,
        TokenKind.INT32,
        TokenKind.INT64,
        TokenKind.INTNATIVE,
        TokenKind.UINT8,
        TokenKind.UINT16,
        TokenKind.UINT32,
        TokenKind.UINT64,
        TokenKind.UINTNATIVE,
        TokenKind.FLOAT16,
        TokenKind.FLOAT32,
        TokenKind.FLOAT64
    ]

    public static let CHAR_LANG_TYPES: Array<TokenKind> = NUMERIC_TYPES.concat([
        TokenKind.RUNE,
        TokenKind.BOOLEAN,
        TokenKind.NOTHING,
        TokenKind.UNIT,
        TokenKind.THISTYPE
    ])

    public static let LITERAL_CONSTANT: Array<TokenKind> = [
        TokenKind.BOOL_LITERAL,
        TokenKind.RUNE_BYTE_LITERAL,
        TokenKind.INTEGER_LITERAL,
        TokenKind.STRING_LITERAL,
        TokenKind.FLOAT_LITERAL,
        TokenKind.RUNE_LITERAL
    ]

    public static let END: Array<TokenKind> = [
        TokenKind.NL,
        TokenKind.SEMI
    ]
}