import '../../token/token_type.dart';
import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

class Unary extends Expression {
  final TokenType operator_;
  final Expression expression;

  Unary(this.operator_, this.expression, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
