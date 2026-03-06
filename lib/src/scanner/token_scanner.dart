part of 'scanner.dart';

extension ScannerTokens on Scanner {
  Token _scanIdentifier() {
    final offset = _reader.offset;
    _reader.cutIn();
    while (_reader.peek().isLetter || _reader.peek().isDecimal) {
      _reader.consume();
    }
    final literal = _reader.cutOut();
    final type = TokenType.fromString(literal);
    return Token(offset, type, literal);
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
    while (true) {
      if (_reader.peek() == 95) { // '_' visual separator
        _reader.consume();
        continue;
      }
      if (_reader.peek().digitValue < numberBase) {
        _reader.consume();
        length++;
      } else {
        break;
      }
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
        if (_reader.peek() == 39) {
          _reader.consume();
          if (_reader.peek() == 39) {
            _reader.consume();
            return Token(offset, TokenType.stringLiteral, _scanTripleQuoteString(39));
          }
          _reader.back();
        }
        return Token(offset, TokenType.charLiteral, _scanChar());
      case 34: // '"'
        _reader.consume();
        if (_reader.peek() == 34) {
          _reader.consume();
          if (_reader.peek() == 34) {
            _reader.consume();
            return Token(offset, TokenType.stringLiteral, _scanTripleQuoteString(34));
          }
          _reader.back();
        }
        return Token(offset, TokenType.stringLiteral, _scanString());
      case 47: // '/'
        _reader.consume();
        final next = _reader.peek();
        if (next == 47 || next == 42) { // '//' or '/*'
          return Token(offset, TokenType.comment, _scanComment());
        }
        if (next == 61) { // '=' -> '/='
          _reader.consume();
          return Token(offset, TokenType.divAssign, "/=");
        }
        return Token(offset, TokenType.div, "/");
      case 64: // '@'
        _reader.consume();
        return Token(offset, TokenType.annotation, "@");
      case 46: // '.'
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

      if (potentialType != TokenType.identifier) {
        type = potentialType;
      } else {
        _reader.back();
        break;
      }
    }
    return Token(offset, type, _reader.cutOut());
  }

  /// Scans a comment: single-line (//) or block (/* */).
  /// Called after the opening '/' has already been consumed.
  String _scanComment() {
    final offset = _reader.offset;
    _reader.cutIn();
    if (_reader.consume() == 47) { // '/' -> single-line comment
      while (_reader.peek() != 10 && _reader.peek() != RuneReader.eof) {
        _reader.consume();
      }
    } else { // '*' -> block comment
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

  /// Scans a normal string enclosed by double quotes (").
  /// Returns only the content (without opening or closing quotes).
  String _scanString() {
    int offset = _reader.offset;
    _reader.cutIn();
    while (true) {
      final r = _reader.peek();
      if (r == 10 || r == RuneReader.eof) {
        _error(offset, "String not terminated");
        break;
      }
      if (r == 34) break; // closing " — stop before consuming
      _reader.consume();
      if (r == 92) _bypassEscape(offset); // '\'
    }
    final content = _reader.cutOut(); // content without closing "
    if (_reader.peek() == 34) _reader.consume(); // consume closing "
    return content;
  }

  /// Bypasses an escape sequence. Assumes the backslash has already been consumed.
  void _bypassEscape(int offset) {
    final r = _reader.peek();
    const escapes = {39, 34, 92, 48, 97, 98, 101, 102, 110, 114, 116, 118};
    if (escapes.contains(r)) {
      _reader.consume();
    } else if (r == 120) { // 'x' — hex escape \xHH, passed through to C
      _reader.consume(); // consume 'x'
      var c = _reader.peek();
      while ((c >= 48 && c <= 57) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102)) {
        _reader.consume();
        c = _reader.peek();
      }
    } else {
      _error(offset, r < 0 ? "Escape sequence not terminated" : "Unknown escape sequence");
    }
  }

  /// Returns content between triple delimiters (without the delimiters themselves).
  String _scanTripleQuoteString(int delimiter) {
    final offset = _reader.offset;
    _reader.cutIn();
    while (true) {
      final r = _reader.peek();
      if (r == RuneReader.eof) {
        _error(offset, "Triple-quoted string not terminated");
        break;
      }
      _reader.consume();
      if (r == delimiter) {
        if (_reader.peek() == delimiter) {
          _reader.consume();
          if (_reader.peek() == delimiter) {
            // Found closing triple. Back up 2 so cutOut ends before 1st closing delimiter.
            _reader.back(2);
            final content = _reader.cutOut();
            // Consume all 3 closing delimiters.
            _reader.consume();
            _reader.consume();
            _reader.consume();
            return content;
          }
        }
      }
    }
    return _reader.cutOut();
  }

  /// Returns the char content (without surrounding single quotes).
  String _scanChar() {
    final offset = _reader.offset;
    _reader.cutIn();
    final r = _reader.peek();
    if (r == 10 || r < 0) {
      _error(offset, "Char not terminated");
      return _reader.cutOut();
    }
    _reader.consume();
    if (r == 92) _bypassEscape(offset);
    final content = _reader.cutOut(); // content without closing '
    if (_reader.peek() != 39) { // '\''
      _error(offset, "Illegal char");
    } else {
      _reader.consume(); // consume closing '
    }
    return content;
  }
}
