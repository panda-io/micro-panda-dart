import '../context.dart';
import '../type/type.dart';
import 'expression.dart';

/// Address-of expression: &x
class RefExpression extends Expression {
  final Expression expression;

  RefExpression(this.expression, super.position);

  @override
  void validate(Context context, Type? expected) {}
}
