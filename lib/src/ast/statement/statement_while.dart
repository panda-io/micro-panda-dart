import '../context.dart';
import '../expression/expression.dart';
import 'statement.dart';

class WhileStatement extends Statement {
  final Expression condition;
  final Statement body;

  WhileStatement(this.condition, this.body, super.position);

  @override
  void validate(Context context) {}
}
