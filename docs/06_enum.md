


3 enum types:



enum Color
    Red
    Green
    Blue



enum OpCode
    Add = 1
    Sub = 2
    Mul = 3
    Div = 4


enum Expression
    Binary(left: &Expression, op: OpCode, right: &Expression)
    Unary(op: OpCode, exp: &Expression)