import 'dart:collection';
import 'package:micro_panda/src/token/token_type.dart';
import 'package:micro_panda/src/token/position.dart';
import 'rune_reader.dart';
import 'expression.dart';

part 'token_scanner.dart';
part 'preprocessor.dart';

class Scanner {
  final SourceFile _file;
  final RuneReader _reader;
  final HashSet<String> _flags;

  final List<int> _indentStack = [0]; 
  int? _indentWidth;
  final Queue<Token> _pendingTokens = Queue();
  Token? _preprocessorToken;
  final List<PreprocessorState> _preprocessors = [];

  bool _isAtLineStart = true;

  Scanner(this._file, String source, this._flags)
      : _reader = RuneReader(_file, source);

  Token nextToken() {
    if (_pendingTokens.isNotEmpty) {
      return _pendingTokens.removeFirst();
    }

    return _scan();
  }

  Token _scan() {
    if (_isAtLineStart) {
      _handleIndentation();
      if (_pendingTokens.isNotEmpty) {
        return _pendingTokens.removeFirst();
      }
    }

    _skipHorizontalSpace();
    
    _reader.cutIn();
    final offset = _reader.offset;
    final rune = _reader.peek();

    if (rune == RuneReader.eof) {
      if (_indentStack.last > 0) {
        _unwindIndents();
        return nextToken();
      }
      return Token(offset, TokenType.eof, "");
    }

    if (rune.isLetter) {
      return _scanIdentifier();
    } else if (rune.isDecimal) {
      return _scanNumber(offset);
    }
    return _scanSpecialCharacters(rune, offset);
  }

  void _skipHorizontalSpace() {
    while (_reader.peek() == 32 || _reader.peek() == 9 || _reader.peek() == 13) {
      _reader.consume();
    }
  }

  void _handleIndentation() {
    _isAtLineStart = false;
    int currentIndent = 0;

    // count current indentation
    while (true) {
      int r = _reader.peek();
      if (r == 32) { // Space
        currentIndent++;
        _reader.consume();
      } else if (r == 9) { // Tab
        _error(_reader.offset, "Tabs are not allowed for indentation");
      } else {
        break;
      }
    }

    int r = _reader.peek();
    if (r == 10 || r == 35 || r == RuneReader.eof) { // \n, #
      return;
    }

    int lastIndent = _indentStack.last;
    if (currentIndent > lastIndent) {
      final diff = currentIndent - lastIndent;
      if (_indentWidth == null) {
        if (diff != 2 && diff != 4) {
          _error(_reader.offset, "Indentation must be 2 or 4 spaces");
        }
        _indentWidth = diff;
      } else if (diff != _indentWidth) {
        _error(_reader.offset, "Mixed indentation not allowed (expected $_indentWidth spaces)");
      }
      _indentStack.add(currentIndent);
      _pendingTokens.add(Token(_reader.offset, TokenType.indent, ""));
    } else if (currentIndent < lastIndent) {
      while (currentIndent < _indentStack.last) {
        _indentStack.removeLast();
        _pendingTokens.add(Token(_reader.offset, TokenType.dedent, ""));
      }
      if (currentIndent != _indentStack.last) {
        _error(_reader.offset, "Indentation error");
      }
    }
  }

  void _unwindIndents() {
    while (_indentStack.last > 0) {
      _indentStack.removeLast();
      _pendingTokens.add(Token(_reader.offset, TokenType.dedent, ""));
    }
  }

  void _error(int offset, String message) {
    throw Exception("Error: ${_file.getPosition(offset)} $message");
  }
}

class Token {
  final int offset;
  final TokenType type;
  final String literal;
  Token(this.offset, this.type, this.literal);
}