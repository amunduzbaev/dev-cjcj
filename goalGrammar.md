# GOAL GRAMMAR

## Notes

Look at [Symbols](https://docs.cangjie-lang.cn/en/docs/0.53.13/spec/source_en/Chapter_Appendix_A.html?highlight=syntax#symbols) if you need it.

## TRANSLATION UNIT

    translationUnit
        : topLevelObject* (end+ mainDefinition)? NL* (topLevelObject (end+ topLevelObject?)*)? EOF
        ;

    end
        : NL | SEMI
        ;

--------------------------------------------------------------------------------

## TOP-LEVEL DEFINITION

    topLevelObject
    : classDefinition
    | functionDefinition
    | variableDeclaration
    | structDefinition
    ;
--------------------------------------------------------------------------------

## CLASS DEFINITION

    classDefinition
        : (classModifierList NL*)? CLASS NL* identifier
        (NL* typeParameters NL*)?
        (NL* UPPERBOUND NL* superClassOrInterfaces)?
        (NL* genericConstraints)?
        NL* classBody
        ;

    superClassOrInterfaces
        : superClass (NL* BITAND NL* superInterfaces)?
        | superInterfaces
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

    typeParameters
        : LT NL* identifier (NL* COMMA NL* identifier)* NL* GT
        ;

    superClass
        : classType
        ;

    classType
        : (identifier NL* DOT  NL*)*  identifier (NL* typeParameters)?
        ;

    typeArguments
        : LT NL* type (NL* COMMA NL* type)* NL* GT
        ;

    superInterfaces
        : interfaceType (NL* BITAND NL* interfaceType )*
        ;

    interfaceType
        : classType
        ;

    genericConstraints
        : WHERE NL* (identifier | THISTYPE) NL* UPPERBOUND NL* upperBounds (NL* COMMA NL* (identifier | THISTYPE) NL* UPPERBOUND NL* upperBounds)*
        ;

    upperBounds
        : type (NL* BITAND NL* type)*
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
        | operatorFunctionDefinition
        | propertyDefinition
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
        : unnamedParameterList (NL* COMMA NL* namedParameterList)? (NL* COMMA NL* classNamedInitParamList)?
        | unnamedParameterList (NL* COMMA NL* classUnnamedInitParamList)? (NL* COMMA NL* classNamedInitParamList)?
        | classUnnamedInitParamList (NL* COMMA NL* classNamedInitParamList)?
        | namedParameterList (NL* COMMA NL* classNamedInitParamList)?
        | classNamedInitParamList
        ;

    classUnnamedInitParamList
        : classUnnamedInitParam (NL* COMMA NL* classUnnamedInitParam)*
        ;

    classNamedInitParamList
        : classNamedInitParam (NL* COMMA NL* classNamedInitParam)*
        ;

    classUnnamedInitParam
        : (classNonStaticMemberModifier NL*)? (LET | VAR) NL* identifier NL* COLON NL* type
        ;

    classNamedInitParam
        : (classNonStaticMemberModifier NL*)? (LET | VAR) NL* identifier NL* NOT NL* COLON NL* type (NL* ASSIGN NL* expression)?
        ;

    classNonStaticMemberModifier
        : PUBLIC
        | PRIVATE
        | PROTECTED
        | INTERNAL
        ;
--------------------------------------------------------------------------------

## INTERFACE DEFINITION

    interfaceDefinition
        : (interfaceModifierList NL*)? INTERFACE NL* identifier
        (NL* typeParameters NL*)?
        (NL* UPPERBOUND NL* superInterfaces)?
        (NL* genericConstraints)?
        (NL* interfaceBody)
        ;

    interfaceBody
        : LCURL end* interfaceMemberDeclaration* end* RCURL
        ;

    interfaceMemberDeclaration
        : (functionDefinition
        | operatorFunctionDefinition
        | propertyDefinition) end*
        ;

    interfaceModifierList
        : (interfaceModifier NL*)+
        ;

    interfaceModifier
        : PUBLIC
        | PROTECTED
        | INTERNAL
        | PRIVATE
        | OPEN
        ;
--------------------------------------------------------------------------------

## FUNCTION DEFINITION

    functionDefinition
        :(functionModifierList NL*)? FUNC
        NL* identifier
        (NL* typeParameters NL*)?
        NL* functionParameters
        (NL* COLON NL* type)?
        (NL* genericConstraints)?
        (NL* block)?
        ;

    operatorFunctionDefinition
        : (functionModifierList NL*)? OPERATOR NL* FUNC
        NL* overloadedOperators
        (NL* typeParameters NL*)?
        NL* functionParameters
        (NL* COLON NL* type)?
        (NL* genericConstraints)?
        (NL* block)?
        ;

    functionParameters
        : (LPAREN (NL* unnamedParameterList ( NL* COMMA NL* namedParameterList)? )? 
            NL* RPAREN NL*)
        | (LPAREN NL* (namedParameterList NL*)? RPAREN NL*)
        ;

    nondefaultParameterList
        : unnamedParameter (NL* COMMA NL* unnamedParameter)* 
            (NL* COMMA NL*  namedParameter)*
        | namedParameter (NL* COMMA NL* namedParameter)*
        ;

    unnamedParameterList
        : unnamedParameter (NL* COMMA NL*  unnamedParameter)*
        ;

    unnamedParameter
        : (identifier | WILDCARD) NL* COLON NL* type
        ;

    namedParameterList
        : (namedParameter | defaultParameter)
        (NL* COMMA NL* (namedParameter | defaultParameter))*
        ;
        
    namedParameter
        : identifier NL* NOT NL* COLON NL* type
        ;

    defaultParameter
        : identifier NL* NOT NL* COLON NL* type NL* ASSIGN NL* expression
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
        | OVERRIDE
        | OPERATOR
        | REDEF
        | MUT
        | UNSAFE
        | CONST
        ;
--------------------------------------------------------------------------------

## VARIABLE DEFINITION

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

## ENUM DEFINITION

    enumDefinition
        : (enumModifier NL*)? ENUM NL* identifier (NL* typeParameters NL*)? 
        (NL* UPPERBOUND NL* superInterfaces)? 
        (NL* genericConstraints)? NL* LCURL end* enumBody end* RCURL
        ;

    enumBody
        : (BITOR NL*)? caseBody (NL* BITOR NL* caseBody)*     
        (NL* 
        ( functionDefinition 
        | operatorFunctionDefinition 
        | propertyDefinition
        ))*
        ;

    caseBody
        : identifier ( NL* LPAREN NL* type (NL* COMMA NL* type)* NL* RPAREN)?
        ;

    enumModifier
        : PUBLIC
        | PROTECTED
        | INTERNAL
        | PRIVATE
        ;
--------------------------------------------------------------------------------

## STRUCT DEFINITION

    structDefinition
        : (structModifier NL*)? STRUCT NL* identifier (NL* typeParameters NL*)? 
        (NL* UPPERBOUND NL* superInterfaces)?
        (NL* genericConstraints)? NL* structBody
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
        | operatorFunctionDefinition
        | propertyDefinition
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
        : unnamedParameterList (NL* COMMA NL* namedParameterList)? (NL* COMMA NL* structNamedInitParamList)?
        | unnamedParameterList (NL* COMMA NL* structUnnamedInitParamList)? (NL* COMMA NL* structNamedInitParamList)?
        | structUnnamedInitParamList (NL* COMMA NL* structNamedInitParamList)?
        | namedParameterList (NL* COMMA NL* structNamedInitParamList)?
        | structNamedInitParamList
        ;

    structUnnamedInitParamList
        : structUnnamedInitParam (NL* COMMA NL* structUnnamedInitParam)*
        ;

    structNamedInitParamList
        : structNamedInitParam (NL* COMMA NL*  structNamedInitParam)*
        ;

    structUnnamedInitParam
        : (structNonStaticMemberModifier NL*)? (LET | VAR) NL* identifier NL* COLON NL* type
        ;

    structNamedInitParam
        : (structNonStaticMemberModifier NL*)? (LET | VAR) NL* identifier NL* NOT NL* COLON NL* type (NL* ASSIGN NL* expression)?
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

## PROPERTY DEFINITION

    propertyDefinition
        : propertyModifier* NL* PROP NL* identifier NL* COLON NL* type NL* propertyBody?
        ;

    propertyBody
        : LCURL end* propertyMemberDeclaration+ end* RCURL
        ;

    propertyMemberDeclaration
        : GET NL* LPAREN RPAREN NL* block end*
        | SET NL* LPAREN identifier RPAREN NL* block end*
        ;

    propertyModifier
        : PUBLIC
        | PRIVATE
        | PROTECTED
        | INTERNAL
        | STATIC
        | OPEN
        | OVERRIDE
        | REDEF
        | MUT
        ;
--------------------------------------------------------------------------------

## MAIN ENTRY DEFINITION

    mainDefinition
        : MAIN
        NL* functionParameters
        (NL* COLON NL* type)?
        NL* block
        ;
--------------------------------------------------------------------------------

## TYPE

type
    : arrowType
    | tupleType
    | prefixType
    | atomicType
    ;

arrowType
    : arrowParameters NL* ARROW NL* type
    ;

arrowParameters
    : LPAREN NL* (type (NL* COMMA NL* type)* NL*)? RPAREN
    ;

tupleType
    : LPAREN NL* type (NL* COMMA NL* type)+ NL* RPAREN
    ;

prefixType
    : prefixTypeOperator type
    ;

prefixTypeOperator
    : QUEST
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

## EXPRESSION

    expression
        : assignmentExpression
        ;

    assignmentExpression
        : leftValueExpressionWithoutWildCard NL* assignmentOperator NL* logicDisjunctionExpression
        | leftValueExpression NL* ASSIGN NL* logicDisjunctionExpression
        | tupleLeftValueExpression NL* ASSIGN NL* logicDisjunctionExpression
        ;

    tupleLeftValueExpression
        : LPAREN NL* (leftValueExpression | tupleLeftValueExpression) (NL* COMMA NL* (leftValueExpression | tupleLeftValueExpression))+ NL* COMMA? NL* RPAREN
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
        : identifier (NL* typeArguments)?
        | type
        | thisSuperExpression
        | leftAuxExpression NL* DOT NL* identifier (NL* typeArguments)?
        | leftAuxExpression callSuffix
        | leftAuxExpression indexAccess
        ;

    assignableSuffix
        : fieldAccess
        | indexAccess
        ;

    fieldAccess
        : NL* DOT NL* identifier
        ;

    logicDisjunctionExpression
        : logicConjunctionExpression (NL* OR NL* logicConjunctionExpression)*
        ;

    logicConjunctionExpression
        : rangeExpression (NL* AND NL* rangeExpression)*
        ;

    rangeExpression
        : bitwiseDisjunctionExpression NL* (CLOSEDRANGEOP | RANGEOP) NL* bitwiseDisjunctionExpression (NL* COLON NL* bitwiseDisjunctionExpression)?
        | bitwiseDisjunctionExpression
        ;

    bitwiseDisjunctionExpression
        : bitwiseXorExpression (NL* BITOR NL* bitwiseXorExpression)*
        ;

    bitwiseXorExpression
        : bitwiseConjunctionExpression (NL* BITXOR NL* bitwiseConjunctionExpression)*
        ;

    bitwiseConjunctionExpression
        : equalityComparisonExpression (NL* BITAND NL* equalityComparisonExpression)*
        ;

    equalityComparisonExpression
        : comparisonOrTypeExpression (NL* equalityOperator NL* comparisonOrTypeExpression)?
        ;

    comparisonOrTypeExpression
        : shiftingExpression (NL* comparisonOperator NL* shiftingExpression)?
        | shiftingExpression (NL* IS NL* type)?
        | shiftingExpression (NL* AS NL* type)?
        ;

    shiftingExpression
        : additiveExpression (NL* shiftingOperator NL* additiveExpression)*
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
        | type NL* DOT NL* identifier
        | postfixExpression NL* DOT NL* identifier (NL* typeArguments)?
        | postfixExpression callSuffix
        | postfixExpression indexAccess
        | postfixExpression NL* DOT NL* identifier callSuffix? trailingLambdaExpression
        | identifier callSuffix? trailingLambdaExpression
        ;

    callSuffix
        : LPAREN NL* (valueArgument (NL* COMMA NL* valueArgument)* NL*)? RPAREN
        ;

    valueArgument
        : identifier NL* COLON NL* expression
        | expression
        ;

    indexAccess
        : LSQUARE NL* (expression | rangeElement) NL* RSQUARE
        ;

    rangeElement
        :  RANGEOP
        | ( CLOSEDRANGEOP | RANGEOP ) NL* expression
        | expression NL* RANGEOP
        ;

    atomicExpression
        : literalConstant
        | collectionLiteral
        | tupleLiteral
        | identifier (NL* typeArguments)?
        | unitLiteral
        | ifExpression
        | matchExpression
        | loopExpression
        | tryExpression
        | jumpExpression
        | numericTypeConvExpr
        | thisSuperExpression
        | parenthesizedExpression
        | lambdaExpression
        ;

    literalConstant
        : IntegerLiteral
        | FloatLiteral
        | RuneLiteral
        | ByteLiteral
        | booleanLiteral
        | stringLiteral
        | ByteStringArrayLiteral
        | unitLiteral
        ;

    booleanLiteral
        : TRUE
        | FALSE
        ;

    stringLiteral
        : lineStringLiteral
        | multiLineStringLiteral
        | MultiLineRawStringLiteral
        ;

    lineStringContent
        :  LineStrText
        ;

    lineStringLiteral
        : QUOTE_OPEN (lineStringExpression | lineStringContent)* QUOTE_CLOSE
        ;

    lineStringExpression
        : StrExprStart SEMI* (expressionOrDeclaration (SEMI+ expressionOrDeclaration?)*) SEMI* RCURL
        ;

    multiLineStringContent
        : MultiLineStrText
        ;

    multiLineStringLiteral
        : TRIPLE_QUOTE_OPEN (multiLineStringExpression | multiLineStringContent)* TRIPLE_QUOTE_CLOSE
        ;

    multiLineStringExpression
        : StrExprStart end* (expressionOrDeclaration (end+ expressionOrDeclaration?)*) end* RCURL
        ;

    collectionLiteral
        : arrayLiteral
        ;

    arrayLiteral 
        : LSQUARE (NL* elements)? NL* RSQUARE 
        ;

    elements    
        : element ( NL* COMMA NL* element )* 
        ;

    element
        : expressionElement
        ;

    expressionElement 
        : expression
        ;

    tupleLiteral
        : LPAREN NL* expression (NL* COMMA NL* expression)+ NL* RPAREN
        ;

    unitLiteral
        : LPAREN NL* RPAREN
        ;

    ifExpression
        : IF NL* LPAREN NL* (LET NL* deconstructPattern NL* BACKARROW NL*)? expression NL* RPAREN NL* block
        (NL* ELSE (NL* ifExpression | NL* block))?
        ;

    deconstructPattern
        : constantPattern
        | wildcardPattern
        | varBindingPattern
        | tuplePattern
        | enumPattern
        ;

    matchExpression
        : MATCH NL* LPAREN NL* expression NL* RPAREN NL* LCURL NL* matchCase+ NL* RCURL
        | MATCH NL* LCURL NL* (CASE NL* (expression | WILDCARD) NL* DOUBLE_ARROW NL* expressionOrDeclaration (end+ expressionOrDeclaration?)*)+ NL* RCURL
        ;

    matchCase
        : CASE NL* pattern NL* patternGuard? NL* DOUBLE_ARROW NL* expressionOrDeclaration (end+ expressionOrDeclaration?)*
        ;

    patternGuard
        : WHERE NL* expression
        ;

    pattern
    : constantPattern
    | wildcardPattern
    | varBindingPattern
    | tuplePattern
    | typePattern
    | enumPattern
    ;

    constantPattern
    : literalConstant NL* ( NL* BITOR NL* literalConstant)*
    ;

    wildcardPattern
    : WILDCARD
    ;

    varBindingPattern
    : identifier
    ;

    tuplePattern
    : LPAREN NL* pattern (NL* COMMA NL* pattern)+ NL* RPAREN
    ;

    typePattern
    : (WILDCARD | identifier) NL* COLON NL* type
    ;

    enumPattern
    : NL* ((userType NL* DOT NL*)? identifier enumPatternParameters?) (NL* BITOR NL* ((userType NL* DOT NL*)? identifier enumPatternParameters?))*
    ;

    enumPatternParameters
    : LPAREN NL* pattern (NL* COMMA NL* pattern)* NL* RPAREN
    ;

    loopExpression
        : forInExpression
        | whileExpression
        | doWhileExpression
        ;

    forInExpression
        : FOR NL* LPAREN NL* patternsMaybeIrrefutable NL* IN NL* expression NL* patternGuard? NL* RPAREN NL* block
        ;

    patternsMaybeIrrefutable
        : wildcardPattern
        | varBindingPattern
        | tuplePattern
        | enumPattern
        ;

    whileExpression
        : WHILE NL* LPAREN NL* (LET NL* deconstructPattern NL* BACKARROW NL*)? expression NL* RPAREN NL* block
        ;

    doWhileExpression
        : DO NL* block NL* WHILE NL* LPAREN NL* expression NL* RPAREN
        ;

    tryExpression
        : TRY NL* block NL* FINALLY NL* block
        | TRY NL* block (NL* CATCH NL* LPAREN NL* catchPattern NL* RPAREN NL* block)+ (NL* FINALLY NL* block)?
        | TRY NL* LPAREN NL* resourceSpecifications NL* RPAREN NL* block
        (NL* CATCH NL* LPAREN NL* catchPattern NL* RPAREN NL* block)* (NL* FINALLY NL* block)?
        ;

    catchPattern
        : wildcardPattern
        | exceptionTypePattern
        ;

    exceptionTypePattern
        : (WILDCARD | identifier) NL* COLON NL* type (NL* BITOR NL* type)*
        ;

    resourceSpecifications
        : resourceSpecification (NL* COMMA NL* resourceSpecification)*
        ;

    resourceSpecification
        : identifier (NL* COLON NL* classType)? NL* ASSIGN NL* expression
        ;

    jumpExpression
        : THROW NL* expression
        | RETURN (NL* expression)?
        | CONTINUE
        | BREAK
        ;

    numericTypeConvExpr
        : numericTypes LPAREN NL* expression NL* RPAREN
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
