import '../context.dart';
import '../expression/expression.dart';
import '../type/type_builtin.dart';
import '../../token/token_type.dart';
import 'statement.dart';

/// Built-in `assert(expr)` statement.
///
/// The compiler captures the source text of [condition] and the source
/// location so the test runner can print a meaningful failure message.
class AssertStatement extends Statement {
  final Expression condition;
  final String sourceText; // e.g. "assert(a == b)"
  final String sourceFile;
  final int sourceLine;

  AssertStatement(
      this.condition, this.sourceText, this.sourceFile, this.sourceLine,
      super.position);

  @override
  void validate(Context context) {
    condition.validate(context, TypeBuiltin(TokenType.typeBool));
  }
}
