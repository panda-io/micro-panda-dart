import '../context.dart';
import '../expression/expression.dart';
import 'statement.dart';

class IfStatement extends Statement {
  final Expression condition;
  final Statement body;
  final Statement? else_;

  IfStatement(this.condition, this.body, this.else_, super.position);

  @override
  void validate(Context context) {}
}
