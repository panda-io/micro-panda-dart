import '../context.dart';
import '../type/type.dart';
import '../type/type_ref.dart';
import 'expression.dart';

/// Address-of expression: &x
class RefExpression extends Expression {
  final Expression expression;

  RefExpression(this.expression, super.position);

  @override
  void validate(Context context, Type? expected) {
    expression.validate(context, null);
    type = expression.type != null ? TypeRef(expression.type!) : null;
  }
}
