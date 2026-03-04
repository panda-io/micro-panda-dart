import '../context.dart';
import '../expression/expression.dart';
import 'statement.dart';

class ReturnStatement extends Statement {
  final Expression? value;

  ReturnStatement(this.value, super.position);

  @override
  void validate(Context context) {}
}
