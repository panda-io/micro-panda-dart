import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

/// Postfix decrement: expr--
class Decrement extends Expression {
  final Expression expression;

  Decrement(this.expression, super.position);

  @override
  void validate(Context context, Type? expected) {
    expression.validate(context, expected);
    type = expression.type;
  }
}
