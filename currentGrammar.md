# Notes
Look at [Symbols](https://docs.cangjie-lang.cn/en/docs/0.53.13/spec/source_en/Chapter_Appendix_A.html?highlight=syntax#symbols) if you need it.

# TRANSLATION UNIT
    translationUnit
        : topLevelObject* (end+ mainDefinition)? NL* (topLevelObject (end+ topLevelObject?)*)? EOF
        ;

    end
        : NL | SEMI
        ;

--------------------------------------------------------------------------------
# TOP-LEVEL DEFINITION
    topLevelObject
    : classDefinition
    | functionDefinition
    | variableDeclaration
    | structDefinition
    ;
--------------------------------------------------------------------------------
# CLASS DEFINITION
    classDefinition
        : (classModifierList NL*)? CLASS NL* identifier
        (NL* UPPERBOUND NL* superClass)?
        NL* classBody
        ;

    classModifierList
        : classModifier+
        ;

    classModifier
        : PUBLIC
        | PROTECTED
        | INTERNAL
        | PRIVATE
        | ABSTRACT
        | OPEN
        ;

    superClass
        : classType
        ;

    classType
        : identifier
        ;

    classBody
        : LCURL end*
            classMemberDeclaration* NL*
            classPrimaryInit? NL* 
            classMemberDeclaration* end* RCURL
        ;

    classMemberDeclaration
        : (classInit
        | staticInit
        | variableDeclaration
        | functionDefinition
        ) end*
        ;

    classInit
        : (classNonStaticMemberModifier | CONST NL*)? INIT NL* functionParameters NL* block
        ;

    staticInit
        : STATIC INIT LPAREN RPAREN
        LCURL
        expressionOrDeclarations?
        RCURL
        ;

    classPrimaryInit
        : (classNonStaticMemberModifier | CONST NL*)?  className NL* LPAREN NL*  
            classPrimaryInitParamLists 
        NL* RPAREN NL*
        LCURL NL*
            (SUPER callSuffix)? end
            expressionOrDeclarations?
        NL* RCURL
        ;

    className
        : identifier
        ;

    classPrimaryInitParamLists
        : unnamedParameterList (NL* COMMA NL* classUnnamedInitParamList)?
        | classUnnamedInitParamList
        ;

    classUnnamedInitParamList
        : classUnnamedInitParam (NL* COMMA NL* classUnnamedInitParam)*
        ;

    classUnnamedInitParam
        : (classNonStaticMemberModifier NL*)? (LET | VAR) NL* identifier NL* COLON NL* type
        ;

    classNonStaticMemberModifier
        : PUBLIC
        | PRIVATE
        | PROTECTED
        | INTERNAL
        ;
--------------------------------------------------------------------------------
# FUNCTION DEFINITION
    functionDefinition
        :(functionModifierList NL*)? FUNC
         NL* identifier
         NL* functionParameters
        (NL* COLON NL* type)?
        (NL* block)?
        ;

    functionParameters
        : (LPAREN (NL* unnamedParameterList)? 
            NL* RPAREN NL*)
        ;

    unnamedParameterList
        : unnamedParameter (NL* COMMA NL*  unnamedParameter)*
        ;

    unnamedParameter
        : (identifier | WILDCARD) NL* COLON NL* type
        ;

    functionModifierList
        : (functionModifier NL*)+
        ;

    functionModifier
        : PUBLIC
        | PRIVATE
        | PROTECTED
        | INTERNAL
        | STATIC
        | OPEN
        | MUT
        | CONST
        ;
--------------------------------------------------------------------------------
# VARIABLE DEFINITION
    variableDeclaration
        : variableModifier* NL* (LET | VAR | CONST) NL* patternsMaybeIrrefutable
            ( (NL* COLON NL* type)? (NL* ASSIGN NL* expression) | (NL* COLON NL* type) )
        ;

    variableModifier
        : PUBLIC
        | PRIVATE
        | PROTECTED
        | INTERNAL
        | STATIC
        ;
--------------------------------------------------------------------------------
# STRUCT DEFINITION
    structDefinition
        : (structModifier NL*)? STRUCT NL* identifier NL* structBody
        ;

    structBody
        : LCURL end*
            structMemberDeclaration* NL*
            structPrimaryInit? NL*
            structMemberDeclaration*
        end* RCURL
        ; 

    structMemberDeclaration
        : (structInit
        | staticInit
        | variableDeclaration
        | functionDefinition
        ) end*
        ;

    structInit
        : (structNonStaticMemberModifier | CONST NL*)? INIT NL* functionParameters NL* block
        ;

    staticInit
        : STATIC INIT LPAREN RPAREN
        LCURL
        expressionOrDeclarations?
        RCURL
        ;

    structPrimaryInit
        : (structNonStaticMemberModifier | CONST NL*)? structName NL* LPAREN NL* structPrimaryInitParamLists? NL* RPAREN NL*
        LCURL NL*
            expressionOrDeclarations?
        NL* RCURL
        ;

    structName
        : identifier
        ;

    structPrimaryInitParamLists
        : unnamedParameterList (NL* COMMA NL* structUnnamedInitParamList)?
        | structUnnamedInitParamList
        ;

    structUnnamedInitParamList
        : structUnnamedInitParam (NL* COMMA NL* structUnnamedInitParam)*
        ;

    structUnnamedInitParam
        : (structNonStaticMemberModifier NL*)? (LET | VAR) NL* identifier NL* COLON NL* type
        ;

    structModifier
        : PUBLIC
        | PROTECTED
        | INTERNAL
        | PRIVATE
        ;

    structNonStaticMemberModifier
        : PUBLIC
        | PROTECTED
        | INTERNAL
        | PRIVATE
        ;
--------------------------------------------------------------------------------
# MAIN ENTRY DEFINITION
    mainDefinition
        : MAIN
        NL* functionParameters
        (NL* COLON NL* type)?
        NL* block
        ;
--------------------------------------------------------------------------------
# TYPE
    // Recheck when need to add Option.
    type
        : atomicType
        ;

    atomicType
        : charLangTypes
        | userType
        | parenthesizedType
        ;

    charLangTypes
        : numericTypes
        | RUNE
        | BOOLEAN
        | Nothing
        | UNIT
        | THISTYPE
        ;

    numericTypes
        : INT8
        | INT16
        | INT32
        | INT64
        | INTNATIVE
        | UINT8
        | UINT16
        | UINT32
        | UINT64
        | UINTNATIVE
        | FLOAT16
        | FLOAT32
        | FLOAT64
        ;

    userType
        : (identifier NL* DOT NL*)* identifier ( NL* typeArguments)?
        ;

    parenthesizedType
        : LPAREN NL* type NL* RPAREN
        ;
--------------------------------------------------------------------------------
# EXPRESSION
    expression
        : assignmentExpression
        ;

    assignmentExpression
        : leftValueExpressionWithoutWildCard NL* assignmentOperator NL*  logicDisjunctionExpression
        | leftValueExpression NL* ASSIGN NL* logicDisjunctionExpression
        ;

    leftValueExpression
        : leftValueExpressionWithoutWildCard
        | WILDCARD
        ;

    leftValueExpressionWithoutWildCard
        : identifier
        | leftAuxExpression NL* assignableSuffix
        ;

    leftAuxExpression
        : identifier
        | type
        | thisSuperExpression
        | leftAuxExpression NL* DOT NL* identifier
        | leftAuxExpression callSuffix
        | leftAuxExpression indexAccess
        ;

    assignableSuffix
        : fieldAccess
        ;

    fieldAccess
        : NL* DOT NL* identifier
        ;

    logicDisjunctionExpression
        : logicConjunctionExpression (NL* OR NL* logicConjunctionExpression)*
        ;

    logicConjunctionExpression
        : bitwiseDisjunctionExpression (NL* AND NL* bitwiseDisjunctionExpression)*
        ;

    bitwiseDisjunctionExpression
        : bitwiseConjunctionExpression (NL* BITOR NL* bitwiseConjunctionExpression)*
        ;

    bitwiseConjunctionExpression
        : equalityComparisonExpression (NL* BITAND NL* equalityComparisonExpression)*
        ;

    equalityComparisonExpression
        : comparisonOrTypeExpression (NL* equalityOperator NL* comparisonOrTypeExpression)?
        ;

    comparisonOrTypeExpression
        : additiveExpression (NL* comparisonOperator NL* additiveExpression)?
        ;

    additiveExpression
        : multiplicativeExpression (NL* additiveOperator NL* multiplicativeExpression)*
        ;

    multiplicativeExpression
        : exponentExpression (NL* multiplicativeOperator NL* exponentExpression)*
        ;

    exponentExpression
        : prefixUnaryExpression (NL* exponentOperator NL* prefixUnaryExpression)*
        ;

    prefixUnaryExpression
        : prefixUnaryOperator* incAndDecExpression
        ;

    incAndDecExpression
        : postfixExpression (INC | DEC )?
        ;

    postfixExpression
        : atomicExpression
        | postfixExpression NL* DOT NL* identifier
        | postfixExpression callSuffix
        ;

    callSuffix
        : LPAREN NL* (valueArgument (NL* COMMA NL* valueArgument)* NL*)? RPAREN
        ;

    valueArgument
        : expression
        ;

    atomicExpression
        : literalConstant
        | unitLiteral
        | ifExpression
        | loopExpression
        | parenthesizedExpression
        ;

    literalConstant
        : IntegerLiteral
        | FloatLiteral
        | RuneLiteral
        | ByteLiteral
        | booleanLiteral
        | stringLiteral
        | unitLiteral
        ;

    booleanLiteral
        : TRUE
        | FALSE
        ;

    stringLiteral
        : lineStringLiteral
        ;

    lineStringContent
        :  LineStrText
        ;

    lineStringLiteral
        : QUOTE_OPEN (lineStringContent)* QUOTE_CLOSE
        ;

    unitLiteral
        : LPAREN NL* RPAREN
        ;

    ifExpression
        : IF NL* LPAREN NL* expression NL* RPAREN NL* block
        (NL* ELSE (NL* ifExpression | NL* block))?
        ;

    deconstructPattern
        : wildcardPattern
        | varBindingPattern
        ;

    pattern
    : wildcardPattern
    | varBindingPattern
    | typePattern
    ;

    varBindingPattern
    : identifier
    ;

    typePattern
    : (WILDCARD | identifier) NL* COLON NL* type
    ;

    loopExpression
        : whileExpression
        ;

    patternsMaybeIrrefutable
        : wildcardPattern
        | varBindingPattern
        ;

    whileExpression
        : WHILE NL* LPAREN NL* expression NL* RPAREN NL* block
        ;

    thisSuperExpression
        : THIS
        | SUPER
        ;

    parenthesizedExpression
        : LPAREN NL* expression NL* RPAREN
        ;

    block
        : LCURL expressionOrDeclarations RCURL
        ;

    expressionOrDeclarations
        : end* (expressionOrDeclaration (end+ expressionOrDeclaration?)*)?
        ;

    expressionOrDeclaration
        : expression
        | varOrfuncDeclaration
        ;

    varOrfuncDeclaration
        : functionDefinition
        | variableDeclaration
        ;

    assignmentOperator
        : ASSIGN
        ;

    equalityOperator
        : NOTEQUAL
        | EQUAL
        ;

    comparisonOperator
        : LT
        | GT
        | LE
        | GE
        ;

    additiveOperator
        : ADD | SUB
        ;

    exponentOperator
        : EXP
        ;

    multiplicativeOperator
        : MUL
        | DIV
        | MOD
        ;

    prefixUnaryOperator
        : SUB
        | NOT
        ;
