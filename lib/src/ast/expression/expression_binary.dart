import '../../token/token_type.dart';
import '../context.dart';
import '../type/type.dart';
import '../type/type_builtin.dart';
import 'expression.dart';

class Binary extends Expression {
  final Expression left;
  final TokenType operator_;
  final Expression right;

  Binary(this.left, this.operator_, this.right, super.position);

  @override
  void validate(Context context, Type? expected) {
    if (operator_.isAssign) {
      left.validate(context, null);
      right.validate(context, left.type);
      if (!context.typesCompatible(left.type, right.type)) {
        context.error(position,
            "type mismatch in assignment: "
            "${Context.typeName(left.type)} = ${Context.typeName(right.type)}");
      }
      type = left.type;
      return;
    }

    switch (operator_) {
      case TokenType.and || TokenType.or:
        left.validate(context, TypeBuiltin(TokenType.typeBool));
        right.validate(context, TypeBuiltin(TokenType.typeBool));
        _checkBool(context, left);
        _checkBool(context, right);
        type = TypeBuiltin(TokenType.typeBool);

      case TokenType.equal || TokenType.notEqual ||
            TokenType.less || TokenType.greater ||
            TokenType.lessEqual || TokenType.greaterEqual:
        left.validate(context, expected);
        right.validate(context, left.type);
        // Both operands should be comparable (numeric or pointer)
        type = TypeBuiltin(TokenType.typeBool);

      default:
        // Arithmetic / bitwise
        left.validate(context, expected);
        right.validate(context, left.type ?? expected);
        if (!context.typesCompatible(left.type, right.type)) {
          context.error(position,
              "type mismatch in '${operator_.literal}': "
              "${Context.typeName(left.type)} vs ${Context.typeName(right.type)}");
        }
        type = left.type ?? right.type ?? expected;
    }
  }

  void _checkBool(Context context, Expression expr) {
    if (expr.type != null &&
        !(expr.type is TypeBuiltin &&
            (expr.type as TypeBuiltin).token == TokenType.typeBool)) {
      context.error(expr.position,
          "expected bool, got ${Context.typeName(expr.type)}");
    }
  }
}
