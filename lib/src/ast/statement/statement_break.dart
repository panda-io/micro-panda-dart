import '../context.dart';
import 'statement.dart';

class BreakStatement extends Statement {
  BreakStatement(super.position);

  @override
  void validate(Context context) {}
}
