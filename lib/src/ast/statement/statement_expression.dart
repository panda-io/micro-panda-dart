import '../context.dart';
import '../expression/expression.dart';
import 'statement.dart';

class ExpressionStatement extends Statement {
  final Expression expression;

  ExpressionStatement(this.expression, super.position);

  @override
  void validate(Context context) {}
}
