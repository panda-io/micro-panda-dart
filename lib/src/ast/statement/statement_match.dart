import '../context.dart';
import '../declaration/enum_decl.dart';
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
  void validate(Context context) {
    expression.validate(context, null);
    for (final arm in arms) {
      final armCtx = context.childScope();
      // Validate pattern expressions
      final pat = arm.pattern;
      if (pat is ExpressionPattern) {
        pat.expression.validate(armCtx, expression.type);
      } else if (pat is DestructurePattern) {
        // Find the variant in all known enums and declare bindings.
        EnumMember? member;
        for (final enm in context.enums.values) {
          for (final m in enm.members) {
            if (m.name == pat.variantName && m.isTagged) {
              member = m;
              break;
            }
          }
          if (member != null) break;
        }
        if (member != null) {
          final fields = member.fields!;
          for (var i = 0; i < pat.bindings.length && i < fields.length; i++) {
            armCtx.declare(pat.bindings[i], fields[i].type, arm.position);
          }
        }
      }
      arm.body.validate(armCtx);
    }
  }
}
