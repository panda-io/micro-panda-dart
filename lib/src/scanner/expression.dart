import 'dart:collection';
import '../token/token_type.dart';

sealed class Expression {
  bool evaluate(HashSet<String> flags);
}

class BinaryExpression implements Expression {
  final Expression left;
  final Expression right;
  final TokenType op;

  BinaryExpression(this.left, this.right, this.op);

  @override
  bool evaluate(HashSet<String> flags) {
    return switch (op) {
      TokenType.or       => left.evaluate(flags) || right.evaluate(flags),
      TokenType.and      => left.evaluate(flags) && right.evaluate(flags),
      TokenType.equal    => left.evaluate(flags) == right.evaluate(flags),
      TokenType.notEqual => left.evaluate(flags) != right.evaluate(flags),
      _ => throw UnsupportedError("Unknown binary operator"),
    };
  }
}

class UnaryExpression implements Expression {
  final Expression expression;
  final TokenType op;

  UnaryExpression(this.expression, this.op);

  @override
  bool evaluate(HashSet<String> flags) {
    if (op == TokenType.not) return !expression.evaluate(flags);
    throw UnsupportedError("Unknown unary operator");
  }
}

class ParenthesesExpression implements Expression {
  final Expression expression;

  ParenthesesExpression(this.expression);

  @override
  bool evaluate(HashSet<String> flags) => expression.evaluate(flags);
}

class IdentifierExpression implements Expression {
  final String name;
  
  IdentifierExpression(this.name);

  @override
  bool evaluate(HashSet<String> flags) => flags.contains(name);
}