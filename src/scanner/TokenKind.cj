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
