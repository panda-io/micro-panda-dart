part of 'parser.dart';

extension ParserExpression on Parser {
  // ── entry point ─────────────────────────────────────────────────────────────

  Expression _parseExpression() => _parseBinary(1);

  // ── precedence climbing ──────────────────────────────────────────────────────

  /// Parse a binary (or assignment) expression with precedence climbing.
  /// All operators with prec >= [minPrec] are consumed.
  /// Assignment operators are right-associative; all others are left-associative.
  Expression _parseBinary(int minPrec) {
    var left = _parseUnary();

    while (true) {
      final prec = _current.type.precedence;
      if (prec == 0 || prec < minPrec) break;

      final op = _current.type;
      final pos = _current.offset;
      _advance();

      // Right-assoc for assignments (stay at same prec), left-assoc otherwise.
      final nextMinPrec = op.isAssign ? prec : prec + 1;
      final right = _parseBinary(nextMinPrec);
      left = Binary(left, op, right, pos);
    }

    return left;
  }

  // ── unary ────────────────────────────────────────────────────────────────────

  Expression _parseUnary() {
    final pos = _current.offset;
    switch (_current.type) {
      case TokenType.minus:
      case TokenType.not:
      case TokenType.complement:
        final op = _current.type;
        _advance();
        return Unary(op, _parseUnary(), pos);
      default:
        return _parsePostfix();
    }
  }

  // ── postfix ──────────────────────────────────────────────────────────────────

  Expression _parsePostfix() {
    var expr = _parsePrimary();

    while (true) {
      final pos = _current.offset;
      switch (_current.type) {
        case TokenType.dot:
          _advance();
          final member = _expectIdentifier();
          expr = MemberAccess(expr, member, pos);
        case TokenType.leftBracket:
          _advance();
          final index = _parseExpression();
          _expect(TokenType.rightBracket);
          expr = Subscript(expr, index, pos);
        case TokenType.leftParen:
          final args = _parseArguments();
          expr = Invocation(expr, args, pos);
        case TokenType.plusPlus:
          _advance();
          expr = Increment(expr, pos);
        case TokenType.minusMinus:
          _advance();
          expr = Decrement(expr, pos);
        default:
          return expr;
      }
    }
  }

  // ── primary ──────────────────────────────────────────────────────────────────

  Expression _parsePrimary() {
    final pos = _current.offset;

    // Literals: int, float, bool, char, string
    switch (_current.type) {
      case TokenType.intLiteral:
      case TokenType.floatLiteral:
      case TokenType.boolLiteral:
      case TokenType.charLiteral:
      case TokenType.stringLiteral:
        final tok = _current.type;
        final val = _current.literal;
        _advance();
        return Literal(tok, val, pos);
      default:
        break;
    }

    // this
    if (_current.type == TokenType.kThis) {
      _advance();
      return This(pos);
    }

    // sizeof(Type)
    if (_current.type == TokenType.kSizeof) {
      _advance();
      _expect(TokenType.leftParen);
      final t = _parseType();
      _expect(TokenType.rightParen);
      return Sizeof(t, pos);
    }

    // Scalar type cast: i32(expr), f64(val)
    if (_current.type.isScalar) {
      final token = _current.type;
      _advance();
      final targetType = TypeBuiltin(token, pos);
      _expect(TokenType.leftParen);
      final val = _parseExpression();
      _expect(TokenType.rightParen);
      return Conversion(targetType, val, pos);
    }

    // Address-of: &expr
    if (_current.type == TokenType.bitAnd) {
      _advance();
      return RefExpression(_parsePrimary(), pos);
    }

    // Array initializer: [expr, ...]
    if (_current.type == TokenType.leftBracket) {
      return _parseArrayInitializer();
    }

    // Grouped expression: (expr)
    if (_current.type == TokenType.leftParen) {
      _advance();
      final expr = _parseExpression();
      _expect(TokenType.rightParen);
      return expr;
    }

    // Identifier: variable, function, class name, etc.
    if (_current.type == TokenType.identifier) {
      final name = _expectIdentifier();
      return Identifier(name, pos);
    }

    _error('expected expression, found ${_current.type.name}');
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  List<Expression> _parseArguments() {
    _expect(TokenType.leftParen);
    final args = <Expression>[];
    if (_current.type == TokenType.rightParen) {
      _advance();
      return args;
    }
    args.add(_parseExpression());
    while (_current.type == TokenType.comma) {
      _advance();
      args.add(_parseExpression());
    }
    _expect(TokenType.rightParen);
    return args;
  }

  ArrayInitializer _parseArrayInitializer() {
    final pos = _current.offset;
    _expect(TokenType.leftBracket);
    final elements = <Expression>[];
    if (_current.type == TokenType.rightBracket) {
      _advance();
      return ArrayInitializer(elements, pos);
    }
    elements.add(_parseExpression());
    while (_current.type == TokenType.comma) {
      _advance();
      elements.add(_parseExpression());
    }
    _expect(TokenType.rightBracket);
    return ArrayInitializer(elements, pos);
  }
}
