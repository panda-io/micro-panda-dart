import '../../token/token_type.dart';
import '../context.dart';
import '../type/type.dart';
import '../type/type_builtin.dart';
import 'expression.dart';

class Unary extends Expression {
  final TokenType operator_;
  final Expression expression;

  Unary(this.operator_, this.expression, super.position);

  @override
  void validate(Context context, Type? expected) {
    expression.validate(context, expected);
    switch (operator_) {
      case TokenType.not:
        if (expression.type != null &&
            !(expression.type is TypeBuiltin &&
                (expression.type as TypeBuiltin).token == TokenType.typeBool)) {
          context.error(position,
              "'!' requires bool, got ${Context.typeName(expression.type)}");
        }
        type = TypeBuiltin(TokenType.typeBool);
      case TokenType.minus:
        type = expression.type;
      case TokenType.complement:
        type = expression.type;
      default:
        type = expression.type;
    }
  }
}
