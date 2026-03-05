import '../../token/token_type.dart';
import '../context.dart';
import '../expression/expression.dart';
import '../type/type_builtin.dart';
import 'statement.dart';

class WhileStatement extends Statement {
  final Expression condition;
  final Statement body;

  WhileStatement(this.condition, this.body, super.position);

  @override
  void validate(Context context) {
    condition.validate(context, TypeBuiltin(TokenType.typeBool));
    body.validate(context.childScope());
  }
}
