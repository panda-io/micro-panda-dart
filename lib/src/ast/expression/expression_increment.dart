import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

/// Postfix increment: expr++
class Increment extends Expression {
  final Expression expression;

  Increment(this.expression, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
