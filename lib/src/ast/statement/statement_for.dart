import '../context.dart';
import '../expression/expression.dart';
import 'statement.dart';

/// for i in range(start, end)
class ForRangeStatement extends Statement {
  final String variable;
  final Expression start;
  final Expression end;
  final Statement body;

  ForRangeStatement(this.variable, this.start, this.end, this.body, super.position);

  @override
  void validate(Context context) {}
}

/// for item in iterable
/// for index, item in iterable
class ForInStatement extends Statement {
  final String? index;   // null if single-variable form
  final String item;
  final Expression iterable;
  final Statement body;

  ForInStatement(this.index, this.item, this.iterable, this.body, super.position);

  @override
  void validate(Context context) {}
}
