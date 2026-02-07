part of 'scanner.dart';

class PreprocessorState {
  String keyword;
  bool evaluated;

  PreprocessorState(this.keyword, this.evaluated);
}

extension ScannerPreprocessor on Scanner {
  static const String _if = "#if";
  static const String _elif = "#elif";
  static const String _else = "#else";
  static const String _end = "#end";

  Token _scanPreprocessor() {
    final offset = _reader.offset;

    _reader.cutIn();
    _reader.consume();

    if (!_reader.peek().isLetter) {
      _error(offset, "Unexpected preprocessor");
    }

    final keyword = "#${_scanIdentifier().literal}";
    if (keyword == _if) {
      _preprocessorToken = _scan();
      final expr = _parseExpression();
      final result = expr.evaluate(_flags);

      if (_preprocessorToken!.type != TokenType.newline) {
        _error(_preprocessorToken!.offset, "Expect newline after expression");
      }

      _preprocessors.add(PreprocessorState(_if, result));
      if (!result) _skipPreprocessor();
      
    } else if (keyword == _elif) {
      if (_preprocessors.isEmpty || _preprocessors.last.keyword == _else) {
        _error(offset, "Unexpected #elif");
      } else if (_preprocessors.last.evaluated) {
        _skipPreprocessor();
      } else {
        _preprocessorToken = _scan();
        final expr = _parseExpression();
        final result = expr.evaluate(_flags);
        
        if (_preprocessorToken!.type != TokenType.newline) {
          _error(_preprocessorToken!.offset, "Expect newline after expression");
        }
        
        _preprocessors.last.evaluated = result;
        if (!result) _skipPreprocessor();
      }
      _preprocessors.last.keyword = _elif;

    } else if (keyword == _else) {
      if (_preprocessors.isEmpty || _preprocessors.last.keyword == _else) {
        _error(offset, "Unexpected #else");
      } else if (_preprocessors.last.evaluated) {
        _skipPreprocessor();
      }
      _preprocessors.last.keyword = _else;

    } else if (keyword == _end) {
      if (_preprocessors.isEmpty) _error(offset, "Unexpected #end");
      _preprocessors.removeLast();
    } else {
      _error(offset, "Unexpected preprocessor directive: $keyword");
    }

    return _scan();
  }

  void _skipPreprocessor() {
    final startCount = _preprocessors.length;

    while (true) {
      while (!_reader.isAtEnd && _reader.peek() != 35) { // '#'
        _reader.consume();
      }
      
      if (_reader.isAtEnd) {
        _error(_reader.offset, "Preprocessor not terminated, expecting #end");
      }

      _reader.cutIn();
      _reader.consume(); // '#'
      final keyword = "#${_scanIdentifier().literal}";

      if (keyword == _if) {
        _preprocessors.add(PreprocessorState(_if, false));
      } else if (keyword == _elif) {
        if (_preprocessors.length == startCount) {
          _reader.back(5);
          break;
        }
        _preprocessors.last.keyword = _elif;
      } else if (keyword == _else) {
        if (_preprocessors.length == startCount) {
          _reader.back(5);
          break;
        }
        _preprocessors.last.keyword = _else;
      } else if (keyword == _end) {
        if (_preprocessors.length == startCount) {
          _reader.back(4);
          break;
        }
        _preprocessors.removeLast();
      }
    }
  }
  
  Expression _parseExpression() => _parseOr();

  Expression _parseOr() {
    var left = _parseAnd();
    while (_preprocessorToken!.type == TokenType.or) {
      _preprocessorToken = _scan();
      left = BinaryExpression(left, _parseAnd(), TokenType.or);
    }
    return left;
  }

  Expression _parseAnd() {
    var left = _parseEquality();
    while (_preprocessorToken!.type == TokenType.and) {
      _preprocessorToken = _scan();
      left = BinaryExpression(left, _parseEquality(), TokenType.and);
    }
    return left;
  }

  Expression _parseEquality() {
    var left = _parseUnary();
    final type = _preprocessorToken!.type;
    if (type == TokenType.equal || type == TokenType.notEqual) {
      _preprocessorToken = _scan();
      left = BinaryExpression(left, _parseUnary(), type);
    }
    return left;
  }

  Expression _parseUnary() {
    if (_preprocessorToken!.type == TokenType.not) {
      _preprocessorToken = _scan();
      return UnaryExpression(_parsePrimary(), TokenType.not);
    }
    return _parsePrimary();
  }

  Expression _parsePrimary() {
    final token = _preprocessorToken;
    if (token!.type == TokenType.identifier) {
      final name = token.literal;
      _preprocessorToken = _scan();
      return IdentifierExpression(name);
    }
    if (token.type == TokenType.leftParen) {
      _preprocessorToken = _scan();
      final expr = _parseExpression();
      if (_preprocessorToken!.type != TokenType.rightParen) {
        _error(token.offset, "Expecting ')'");
      }
      _preprocessorToken = _scan();
      return ParenthesesExpression(expr);
    }
    _error(token.offset, "Invalid expression in preprocessor");
    return IdentifierExpression("invalid");
  }
}