part of 'parser.dart';

extension ParserStatement on Parser {
  // ── block ────────────────────────────────────────────────────────────────────

  /// Parse an indented block: indent → stmts → dedent.
  Block _parseBlock() {
    final pos = _current.offset;
    _expectIndent();
    _skipNewlines();
    final stmts = <Statement>[];
    while (_current.type != TokenType.dedent && _current.type != TokenType.eof) {
      stmts.add(_parseStatement());
      _skipNewlines();
    }
    _expectDedent();
    return Block(stmts, pos);
  }

  // ── statement dispatch ───────────────────────────────────────────────────────

  Statement _parseStatement() {
    final pos = _current.offset;
    switch (_current.type) {
      case TokenType.kIf:
        return _parseIfStatement();
      case TokenType.kWhile:
        return _parseWhileStatement();
      case TokenType.kFor:
        return _parseForStatement();
      case TokenType.kMatch:
        return _parseMatchStatement();
      case TokenType.kReturn:
        _advance();
        if (_current.type == TokenType.newline) {
          _expectNewline();
          return ReturnStatement(null, pos);
        }
        final value = _parseExpression();
        _expectNewline();
        return ReturnStatement(value, pos);
      case TokenType.kBreak:
        _advance();
        _expectNewline();
        return BreakStatement(pos);
      case TokenType.kContinue:
        _advance();
        _expectNewline();
        return ContinueStatement(pos);
      case TokenType.kVar:
      case TokenType.kVal:
      case TokenType.kConst:
        return _parseDeclarationStatement();
      default:
        final expr = _parseExpression();
        _expectNewline();
        return ExpressionStatement(expr, pos);
    }
  }

  // ── if / else ────────────────────────────────────────────────────────────────

  IfStatement _parseIfStatement() {
    final pos = _current.offset;
    _expect(TokenType.kIf);
    final condition = _parseExpression();
    _expectNewline();
    final body = _parseBlock();

    Statement? elseClause;
    if (_current.type == TokenType.kElse) {
      _advance(); // consume 'else'
      if (_current.type == TokenType.kIf) {
        elseClause = _parseIfStatement(); // else-if chain (no newline consumed)
      } else {
        _expectNewline();
        elseClause = _parseBlock();
      }
    }

    return IfStatement(condition, body, elseClause, pos);
  }

  // ── while ────────────────────────────────────────────────────────────────────

  WhileStatement _parseWhileStatement() {
    final pos = _current.offset;
    _expect(TokenType.kWhile);
    final condition = _parseExpression();
    _expectNewline();
    final body = _parseBlock();
    return WhileStatement(condition, body, pos);
  }

  // ── for ──────────────────────────────────────────────────────────────────────

  /// Disambiguates:
  ///   for i in range(start, end)   → ForRangeStatement
  ///   for item in iterable         → ForInStatement(null, item, ...)
  ///   for index, item in iterable  → ForInStatement(index, item, ...)
  Statement _parseForStatement() {
    final pos = _current.offset;
    _expect(TokenType.kFor);

    final first = _expectIdentifier();

    String? index;
    String item;
    if (_current.type == TokenType.comma) {
      _advance();
      index = first;
      item = _expectIdentifier();
    } else {
      item = first;
    }

    _expect(TokenType.kIn);

    // range(...) shorthand — only for single-variable form
    if (index == null && _current.type == TokenType.kRange) {
      _advance();
      _expect(TokenType.leftParen);
      final start = _parseExpression();
      _expect(TokenType.comma);
      final end = _parseExpression();
      _expect(TokenType.rightParen);
      _expectNewline();
      final body = _parseBlock();
      return ForRangeStatement(item, start, end, body, pos);
    }

    final iterable = _parseExpression();
    _expectNewline();
    final body = _parseBlock();
    return ForInStatement(index, item, iterable, body, pos);
  }

  // ── match ────────────────────────────────────────────────────────────────────

  MatchStatement _parseMatchStatement() {
    final pos = _current.offset;
    _expect(TokenType.kMatch);
    final expr = _parseExpression();
    _expectNewline();
    _expectIndent();
    _skipNewlines();

    final arms = <MatchArm>[];
    while (_current.type != TokenType.dedent && _current.type != TokenType.eof) {
      arms.add(_parseMatchArm());
      _skipNewlines();
    }
    _expectDedent();

    return MatchStatement(expr, arms, pos);
  }

  MatchArm _parseMatchArm() {
    final pos = _current.offset;
    final pattern = _parseMatchPattern();
    _expect(TokenType.colon);

    // Arm body: indented block or single statement on the same line.
    Statement body;
    if (_current.type == TokenType.newline) {
      _advance();
      body = _parseBlock();
    } else {
      body = _parseStatement();
    }

    return MatchArm(pattern, body, pos);
  }

  MatchPattern _parseMatchPattern() {
    // Wildcard: _
    if (_current.type == TokenType.identifier && _current.literal == '_') {
      _advance();
      return WildcardPattern();
    }

    // Identifier-based: destructure or plain name / qualified name
    if (_current.type == TokenType.identifier) {
      final name = _current.literal;
      final namePos = _current.offset;
      _advance();

      // Destructure pattern: VariantName(binding1, binding2, ...)
      if (_current.type == TokenType.leftParen) {
        _advance();
        final bindings = <String>[];
        if (_current.type != TokenType.rightParen) {
          bindings.add(_expectIdentifier());
          while (_current.type == TokenType.comma) {
            _advance();
            bindings.add(_expectIdentifier());
          }
        }
        _expect(TokenType.rightParen);
        return DestructurePattern(name, bindings);
      }

      // Plain identifier or qualified name: SomeIdent, Color.Red
      Expression expr = Identifier(name, namePos);
      while (_current.type == TokenType.dot) {
        final dotPos = _current.offset;
        _advance();
        final member = _expectIdentifier();
        expr = MemberAccess(expr, member, dotPos);
      }
      return ExpressionPattern(expr);
    }

    // Literal pattern
    final expr = _parseExpression();
    return ExpressionPattern(expr);
  }

  // ── local declaration ────────────────────────────────────────────────────────

  DeclarationStatement _parseDeclarationStatement() {
    final pos = _current.offset;
    final keyword = _current.type;
    _advance();

    final name = _expectIdentifier();

    // const must use '= value'
    if (keyword == TokenType.kConst) {
      _expect(TokenType.assign);
      final value = _parseExpression();
      _expectNewline();
      return DeclarationStatement(keyword, name, null, value, pos);
    }

    // := type inference
    if (_current.type == TokenType.inferAssign) {
      _advance();
      final value = _parseExpression();
      _expectNewline();
      return DeclarationStatement(keyword, name, null, value, pos);
    }

    // explicit type annotation
    _expect(TokenType.colon);
    final type = _parseType();

    if (_current.type == TokenType.assign) {
      _advance();
      final value = _parseExpression();
      _expectNewline();
      return DeclarationStatement(keyword, name, type, value, pos);
    }

    _expectNewline();
    return DeclarationStatement(keyword, name, type, null, pos);
  }
}
