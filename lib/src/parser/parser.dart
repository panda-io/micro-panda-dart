import 'dart:collection';

import '../ast/annotation.dart';
import '../ast/module.dart';
import '../ast/declaration/class_decl.dart';
import '../ast/declaration/enum_decl.dart';
import '../ast/declaration/function_decl.dart';
import '../ast/declaration/parameter.dart';
import '../ast/declaration/variable_decl.dart';
import '../ast/expression/expression.dart';
import '../ast/expression/expression_array_init.dart';
import '../ast/expression/expression_binary.dart';
import '../ast/expression/expression_conversion.dart';
import '../ast/expression/expression_decrement.dart';
import '../ast/expression/expression_identifier.dart';
import '../ast/expression/expression_increment.dart';
import '../ast/expression/expression_invocation.dart';
import '../ast/expression/expression_literal.dart';
import '../ast/expression/expression_member_access.dart';
import '../ast/expression/expression_ref.dart';
import '../ast/expression/expression_sizeof.dart';
import '../ast/expression/expression_subscript.dart';
import '../ast/expression/expression_this.dart';
import '../ast/expression/expression_unary.dart';
import '../ast/statement/statement.dart';
import '../ast/statement/statement_block.dart';
import '../ast/statement/statement_break.dart';
import '../ast/statement/statement_continue.dart';
import '../ast/statement/statement_declaration.dart';
import '../ast/statement/statement_expression.dart';
import '../ast/statement/statement_for.dart';
import '../ast/statement/statement_if.dart';
import '../ast/statement/statement_match.dart';
import '../ast/statement/statement_return.dart';
import '../ast/statement/statement_while.dart';
import '../ast/type/type.dart';
import '../ast/type/type_array.dart';
import '../ast/type/type_builtin.dart';
import '../ast/type/type_name.dart';
import '../ast/type/type_ref.dart';
import '../scanner/scanner.dart';
import '../token/position.dart';
import '../token/token_type.dart';

part 'parser_module.dart';
part 'parser_declaration.dart';
part 'parser_statement.dart';
part 'parser_expression.dart';
part 'parser_types.dart';

class Parser {
  final Scanner _scanner;
  final SourceFile file;
  late Token _current;
  final _peekBuffer = Queue<Token>();

  Parser(SourceFile file, String source, Set<String> flags)
      : _scanner = Scanner(file, source, HashSet.of(flags)),
        file = file {
    _advance();
  }

  // ── token navigation ────────────────────────────────────────────────────────

  /// Read next non-comment token from the scanner.
  Token _nextNonComment() {
    Token t;
    do {
      t = _scanner.nextToken();
    } while (t.type == TokenType.comment);
    return t;
  }

  /// Advance to the next non-comment token (pulls from peek buffer first).
  void _advance() {
    _current = _peekBuffer.isNotEmpty
        ? _peekBuffer.removeFirst()
        : _nextNonComment();
  }

  /// Peek at the 1st token ahead (without consuming).
  Token _peek1() {
    if (_peekBuffer.isEmpty) _peekBuffer.addLast(_nextNonComment());
    return _peekBuffer.first;
  }

  /// Peek at the 2nd token ahead (without consuming).
  Token _peek2() {
    while (_peekBuffer.length < 2) { _peekBuffer.addLast(_nextNonComment()); }
    return _peekBuffer.elementAt(1);
  }

  /// Peek at the 3rd token ahead (without consuming).
  Token _peek3() {
    while (_peekBuffer.length < 3) { _peekBuffer.addLast(_nextNonComment()); }
    return _peekBuffer.elementAt(2);
  }

  /// Consume and return the current token, then advance.
  Token _consume() {
    final t = _current;
    _advance();
    return t;
  }

  /// Expect the current token to be [type], consume it, and advance.
  /// Throws a parse error if the token does not match.
  Token _expect(TokenType type) {
    if (_current.type != type) {
      _error('expected ${type.literal ?? type.name}, '
          'but found ${_current.literal.isNotEmpty ? '"${_current.literal}"' : _current.type.name}');
    }
    return _consume();
  }

  /// Consume a newline token (end of statement/header).
  void _expectNewline() => _expect(TokenType.newline);

  /// Consume an indent token (start of indented block).
  void _expectIndent() => _expect(TokenType.indent);

  /// Consume a dedent token (end of indented block).
  void _expectDedent() => _expect(TokenType.dedent);

  /// Skip any consecutive newline tokens (blank lines).
  void _skipNewlines() {
    while (_current.type == TokenType.newline) {
      _advance();
    }
  }

  // ── error handling ───────────────────────────────────────────────────────────

  Never _error(String message) {
    throw Exception('Parse error at offset ${_current.offset}: $message');
  }

  // ── annotations ──────────────────────────────────────────────────────────────

  /// Parses zero or more annotations (@name or @name("template")) that precede
  /// a declaration. Each annotation must be on its own line.
  List<Annotation> _parseAnnotations() {
    final annotations = <Annotation>[];
    while (_current.type == TokenType.annotation) {
      _advance(); // consume '@'
      final name = _expectIdentifier();
      String? template;
      if (_current.type == TokenType.leftParen) {
        _advance(); // consume '('
        if (_current.type != TokenType.stringLiteral) {
          _error('expected string literal in annotation argument');
        }
        template = _current.literal;
        _advance();
        _expect(TokenType.rightParen);
      }
      _expectNewline();
      _skipNewlines();
      annotations.add(Annotation(name, template: template));
    }
    return annotations;
  }

  // ── entry point ──────────────────────────────────────────────────────────────

  Module parseModule(String path) => _parseModule(path);
}
