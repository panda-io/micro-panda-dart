import 'dart:collection';
import 'package:test/test.dart';
import 'package:micro_panda/src/scanner/scanner.dart';
import 'package:micro_panda/src/token/token_type.dart';
import 'package:micro_panda/src/token/position.dart';

void main() {
  group('Scanner Tests', () {
    late HashSet<String> flags;

    setUp(() {
      flags = HashSet<String>();
    });

    List<Token> scan(String source) {
      final file = SourceFile("test.mpd", 0, source.length);
      final scanner = Scanner(file, source, flags);
      final tokens = <Token>[];
      while (true) {
        final token = scanner.nextToken();
        tokens.add(token);
        if (token.type == TokenType.eof) break;
      }
      return tokens;
    }

    test('Scans identifiers and numbers', () {
      final tokens = scan("abc 123 12.34");
      expect(tokens.map((t) => t.type).toList(), [
        TokenType.identifier,
        TokenType.intLiteral,
        TokenType.floatLiteral,
        TokenType.eof,
      ]);
      expect(tokens[0].literal, "abc");
      expect(tokens[1].literal, "123");
      expect(tokens[2].literal, "12.34");
    });

    test('Scans number bases', () {
      final tokens = scan("0xFF 0b10 0o77");
      expect(tokens.map((t) => t.type).toList(), [
        TokenType.intLiteral,
        TokenType.intLiteral,
        TokenType.intLiteral,
        TokenType.eof,
      ]);
    });

    test('Scans strings and chars', () {
      final tokens = scan("'a' \"hello\" `raw`");
      expect(tokens.map((t) => t.type).toList(), [
        TokenType.charLiteral,
        TokenType.stringLiteral,
        TokenType.stringLiteral,
        TokenType.eof,
      ]);
    });

    test('Scans comments', () {
      final tokens = scan("// line\n/* block */");
      expect(tokens.map((t) => t.type).toList(), [
        TokenType.comment,
        TokenType.newline,
        TokenType.comment,
        TokenType.eof,
      ]);
    });

    test('Handles indentation', () {
      final source = "a\n  b\n    c\n  d";
      final tokens = scan(source);
      
      final types = tokens.map((t) => t.type).toList();
      expect(types, [
        TokenType.identifier,
        TokenType.newline,
        TokenType.indent, // +2
        TokenType.identifier,
        TokenType.newline,
        TokenType.indent, // +4
        TokenType.identifier,
        TokenType.newline,
        TokenType.dedent, // -4 -> 2
        TokenType.identifier,
        TokenType.dedent, // -2 -> 0 (at EOF)
        TokenType.eof,
      ]);
    });

    test('Errors on mixed indentation', () {
      // First indent establishes width=2. 
      // Second indent adds 4 spaces (total 6). Diff is 4. 
      // 4 != 2, so this should fail.
      final source = "a\n  b\n      c"; 
      expect(() => scan(source), throwsException);
    });

    test('Errors on tabs', () {
      expect(() => scan("\ta"), throwsException);
    });

    test('Preprocessor #if true', () {
      flags.add("TEST");
      final source = "#if TEST\npass\n#end";
      final tokens = scan(source);
      expect(tokens.map((t) => t.type), contains(TokenType.identifier));
      expect(tokens.firstWhere((t) => t.type == TokenType.identifier).literal, "pass");
    });

    test('Preprocessor #if false', () {
      final source = "#if TEST\nfail\n#end";
      final tokens = scan(source);
      expect(tokens.map((t) => t.type), isNot(contains(TokenType.identifier)));
    });

    test('Preprocessor #else', () {
      final source = "#if TEST\nfail\n#else\npass\n#end";
      final tokens = scan(source);
      expect(tokens.map((t) => t.type), contains(TokenType.identifier));
      expect(tokens.firstWhere((t) => t.type == TokenType.identifier).literal, "pass");
    });
  });
}