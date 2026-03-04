import '../context.dart';
import '../expression/expression.dart';
import 'statement.dart';

/// A single arm of a match statement.
/// pattern is the raw expression before ':', body is the indented block.
class MatchArm {
  final MatchPattern pattern;
  final Statement body;
  final int position;

  MatchArm(this.pattern, this.body, this.position);
}

/// Base class for match patterns.
sealed class MatchPattern {}

/// Wildcard: _
class WildcardPattern extends MatchPattern {}

/// A plain expression pattern: literal or enum member (Color.Red, 0x01, etc.)
class ExpressionPattern extends MatchPattern {
  final Expression expression;
  ExpressionPattern(this.expression);
}

/// Tagged enum destructuring: Binary(left, op, right)
class DestructurePattern extends MatchPattern {
  final String variantName;
  final List<String> bindings;
  DestructurePattern(this.variantName, this.bindings);
}

class MatchStatement extends Statement {
  final Expression expression;
  final List<MatchArm> arms;

  MatchStatement(this.expression, this.arms, super.position);

  @override
  void validate(Context context) {}
}
