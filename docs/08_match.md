



match op_code
    0x01:
        return left + right
    0x02:
        return left - right


enum Color
    Red
    Green
    Blue


match color
    Color.Red:
        return "red"

    Color.Green:
        return "green"

    Color.Blue:
        return "blue"

    _:
        return "unknown"



enum Expression
    Binary(left: &Expression, op: OpCode, right: &Expression)
    Unary(op: OpCode, exp: &Expression)


match expression:
    Binary(left: &Expression, op: OpCode, right: &Expression):
        print(left, op, right)

    Unary(op: OpCode, exp: &Expression):
        print(op, exp)