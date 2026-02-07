part of 'scanner.dart';

extension ScannerTokens on Scanner {
  Token _scanIdentifier() {
    _reader.cutIn();
    while (_reader.peek().isLetter || _reader.peek().isDecimal) {
      _reader.consume();
    }
    final literal = _reader.cutOut();
    final type = TokenType.fromString(literal); 
    return Token(_reader.offset, type, literal);
  }

  Token _scanNumber() {
    final offset = _reader.offset;
    _reader.cutIn();

    var type = TokenType.intLiteral;
    int rune = _reader.consume();

    if (rune != 46) { // '.'
      if (rune == 48) { // '0'
        rune = _reader.peek();
        if (rune != 46) { // Not '0.'
          int numberBase = 10;
          final lowerRune = rune.toLower();
          
          if (lowerRune == 120) { // 'x'
            numberBase = 16;
            _reader.consume();
          } else if (lowerRune == 98) { // 'b'
            numberBase = 2;
            _reader.consume();
          } else if (lowerRune == 111) { // 'o'
            numberBase = 8;
            _reader.consume();
          } else if (rune.isDecimal) {
            _error(offset, "Illegal integer (leading zero not allowed)");
            return Token(offset, TokenType.illegal, _reader.cutOut());
          }

          if (numberBase != 10) {
            if (_bypassDigits(numberBase) == 0) {
              _error(offset, "Illegal integer (no digits after base prefix)");
              return Token(offset, TokenType.illegal, _reader.cutOut());
            }
            if (_reader.peek() == 46) {
              _error(offset, "Illegal radix point in non-decimal number");
              return Token(offset, TokenType.illegal, _reader.cutOut());
            }
            return Token(offset, type, _reader.cutOut());
          }
        }
      } else {
        _bypassDigits(10);
      }
    }

    if (_reader.peek() == 46) { // '.'
      _reader.consume();
      type = TokenType.floatLiteral;
      if (_bypassDigits(10) == 0) {
        _error(offset, "Illegal fraction (no digits after decimal point)");
        return Token(offset, TokenType.illegal, _reader.cutOut());
      }
    }

    return Token(offset, type, _reader.cutOut());
  }

  int _bypassDigits(int numberBase) {
    int length = 0;
    while (_reader.peek().digitValue < numberBase) {
      _reader.consume();
      length++;
    }
    return length;
  }

  Token _scanSpecialCharacters(int firstRune) {
    final offset = _reader.offset;

    switch (firstRune) {
      case 10: // '\n'
        _reader.consume();
        _isAtLineStart = true;
        return Token(offset, TokenType.newline, "\n");
      case 39: // '\''
        _reader.consume();
        return Token(offset, TokenType.charLiteral, _scanChar(offset));
      case 34: // '"'
        _reader.consume();
        return Token(offset, TokenType.stringLiteral, _scanString(offset));
      case 96: // '`'
        _reader.consume();
        return Token(offset, TokenType.stringLiteral, _scanRawString(offset));
      case 47: // '/'
        final next = _reader.peek();
        if (next == 47 || next == 42) { // '//' or '/*'
          return Token(offset, TokenType.comment, _scanComment(offset));
        }
        break; // continue to operator scanning
      case 64: // '@'
        _reader.consume();
        return Token(offset, TokenType.annotation, "@");
      case 46: // '.'
        if (_reader.peek().isDecimal) {
           _reader.back();
           return _scanNumber();
        }
        _reader.consume();
        return Token(offset, TokenType.dot, ".");
      case 35: // '#'
        return _scanPreprocessor();
    }

    // operators and delimiters
    var type = TokenType.illegal;
    _reader.cutIn();
    while (_reader.peek() >= 0) {
      _reader.consume();
      final literal = _reader.cutOut();
      final potentialType = TokenType.fromString(literal);
      
      if (potentialType != TokenType.illegal) {
        type = potentialType;
      } else {
        _reader.back();
        break;
      }
    }
    return Token(offset, type, _reader.cutOut());
  }

  /// scans a comment, which can be either a single-line comment starting with '//' or a multi-line comment enclosed by '/*' and '*/'.
  String _scanComment(int offset) {
    _reader.cutIn();
    if (_reader.consume() == 47) { // '/' -> single line comment
      while (_reader.peek() != 10 && _reader.peek() != RuneReader.eof) {
        _reader.consume();
      }
    } else { // '*' -> 多行注释
      bool terminated = false;
      while (!_reader.isAtEnd) {
        final r = _reader.consume();
        if (r == 42 && _reader.peek() == 47) { // '*/'
          _reader.consume();
          terminated = true;
          break;
        }
      }
      if (!terminated) _error(offset, "Comment not terminated");
    }
    return _reader.cutOut();
  }

  /// scans a normal string, which is enclosed by double quotes (") and may contain escape sequences.
  String _scanString(int offset) {
    _reader.cutIn();
    while (true) {
      final r = _reader.peek();
      if (r == 10 || r == RuneReader.eof) {
        _error(offset, "String not terminated");
        break;
      }
      _reader.consume();
      if (r == 34) break; // '"'
      if (r == 92) _bypassEscape(offset); // '\'
    }
    return _reader.cutOut();
  }

  /// bypasses an escape sequence in a string literal. It assumes that the initial backslash has already been consumed and the current position is at the escape character.
  void _bypassEscape(int offset) {
    final r = _reader.peek();
    const escapes = {39, 34, 92, 48, 97, 98, 101, 102, 110, 114, 116, 118};
    if (escapes.contains(r)) {
      _reader.consume();
    } else {
      _error(offset, r < 0 ? "Escape sequence not terminated" : "Unknown escape sequence");
    }
  }

  /// scans a raw string, which is enclosed by backticks (`) and does not process escape sequences.
  String _scanRawString(int offset) {
    _reader.cutIn();
    while (true) {
      final r = _reader.peek();
      if (r == RuneReader.eof) {
        _error(offset, "Raw string not terminated");
        break;
      }
      _reader.consume();
      if (r == 96) break; // '`'
    }
    return _reader.cutOut();
  }
  
  String _scanChar(int offset) {
    _reader.cutIn();
    final r = _reader.peek();
    if (r == 10 || r < 0) {
      _error(offset, "Char not terminated");
      return _reader.cutOut();
    }
    _reader.consume();
    if (r == 92) _bypassEscape(offset);
    if (_reader.peek() != 39) { // '\''
      _error(offset, "Illegal char");
    } else {
      _reader.consume();
    }
    return _reader.cutOut();
  }
}