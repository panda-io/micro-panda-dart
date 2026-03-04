import 'dart:collection';

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
  late Token _current;

  Parser(SourceFile file, String source, Set<String> flags)
      : _scanner = Scanner(file, source, HashSet.of(flags)) {
    _advance();
  }

  // ── token navigation ────────────────────────────────────────────────────────

  /// Advance to the next non-comment token.
  void _advance() {
    do {
      _current = _scanner.nextToken();
    } while (_current.type == TokenType.comment);
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

  // ── entry point ──────────────────────────────────────────────────────────────

  Module parseModule(String path) => _parseModule(path);
}
