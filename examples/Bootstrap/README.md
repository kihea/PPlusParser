Compiles a legal string to a algorithm readable grammar:

productionRule -> %token 'literal' ('subexpression' | [regexp])? 
otherRule -> productionRule | %token
otherOtherRule -> productionRule 'literal'?
---->

{
    symbols:  [
        {token: 'token'}, {literal: 'literal'} ...
    ]
}

This program uses itself to compile into a readable grammar, in that the legal string follows a predefined grammar.
