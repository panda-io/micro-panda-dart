import 'dart:collection';
import 'package:test/test.dart';
import 'package:micro_panda/src/scanner/expression.dart';
import 'package:micro_panda/src/token/token_type.dart';

void main() {
  group('Expression Evaluation', () {
    late HashSet<String> flags;

    setUp(() {
      flags = HashSet<String>();
      flags.add('DEBUG');
      flags.add('LINUX');
    });

    test('IdentifierExpression evaluates correctly', () {
      expect(IdentifierExpression('DEBUG').evaluate(flags), isTrue);
      expect(IdentifierExpression('WINDOWS').evaluate(flags), isFalse);
    });

    test('UnaryExpression evaluates NOT correctly', () {
      // !DEBUG -> false
      expect(
        UnaryExpression(IdentifierExpression('DEBUG'), TokenType.not)
            .evaluate(flags),
        isFalse,
      );
      // !WINDOWS -> true
      expect(
        UnaryExpression(IdentifierExpression('WINDOWS'), TokenType.not)
            .evaluate(flags),
        isTrue,
      );
    });

    test('UnaryExpression throws on unknown operator', () {
      expect(
        () => UnaryExpression(IdentifierExpression('DEBUG'), TokenType.plus)
            .evaluate(flags),
        throwsUnsupportedError,
      );
    });

    test('BinaryExpression evaluates OR correctly', () {
      // DEBUG || WINDOWS -> true
      expect(
        BinaryExpression(
          IdentifierExpression('DEBUG'),
          IdentifierExpression('WINDOWS'),
          TokenType.or,
        ).evaluate(flags),
        isTrue,
      );

      // WINDOWS || MACOS -> false
      expect(
        BinaryExpression(
          IdentifierExpression('WINDOWS'),
          IdentifierExpression('MACOS'),
          TokenType.or,
        ).evaluate(flags),
        isFalse,
      );
    });

    test('BinaryExpression evaluates AND correctly', () {
      // DEBUG && LINUX -> true
      expect(
        BinaryExpression(
          IdentifierExpression('DEBUG'),
          IdentifierExpression('LINUX'),
          TokenType.and,
        ).evaluate(flags),
        isTrue,
      );

      // DEBUG && WINDOWS -> false
      expect(
        BinaryExpression(
          IdentifierExpression('DEBUG'),
          IdentifierExpression('WINDOWS'),
          TokenType.and,
        ).evaluate(flags),
        isFalse,
      );
    });

    test('BinaryExpression evaluates EQUAL correctly', () {
      // DEBUG == LINUX (true == true) -> true
      expect(
        BinaryExpression(
          IdentifierExpression('DEBUG'),
          IdentifierExpression('LINUX'),
          TokenType.equal,
        ).evaluate(flags),
        isTrue,
      );

      // DEBUG == WINDOWS (true == false) -> false
      expect(
        BinaryExpression(
          IdentifierExpression('DEBUG'),
          IdentifierExpression('WINDOWS'),
          TokenType.equal,
        ).evaluate(flags),
        isFalse,
      );
    });

    test('BinaryExpression evaluates NOT_EQUAL correctly', () {
      // DEBUG != WINDOWS (true != false) -> true
      expect(
        BinaryExpression(
          IdentifierExpression('DEBUG'),
          IdentifierExpression('WINDOWS'),
          TokenType.notEqual,
        ).evaluate(flags),
        isTrue,
      );

      // DEBUG != LINUX (true != true) -> false
      expect(
        BinaryExpression(
          IdentifierExpression('DEBUG'),
          IdentifierExpression('LINUX'),
          TokenType.notEqual,
        ).evaluate(flags),
        isFalse,
      );
    });

    test('BinaryExpression throws on unknown operator', () {
      expect(
        () => BinaryExpression(
          IdentifierExpression('DEBUG'),
          IdentifierExpression('LINUX'),
          TokenType.plus,
        ).evaluate(flags),
        throwsUnsupportedError,
      );
    });

    test('ParenthesesExpression evaluates correctly', () {
      // (DEBUG) -> true
      expect(
        ParenthesesExpression(IdentifierExpression('DEBUG')).evaluate(flags),
        isTrue,
      );
    });

    test('Complex expression evaluation', () {
      // DEBUG && (WINDOWS || !MACOS)
      // true && (false || !false) -> true && true -> true
      final expr = BinaryExpression(
        IdentifierExpression('DEBUG'),
        ParenthesesExpression(
          BinaryExpression(
            IdentifierExpression('WINDOWS'),
            UnaryExpression(IdentifierExpression('MACOS'), TokenType.not),
            TokenType.or,
          ),
        ),
        TokenType.and,
      );

      expect(expr.evaluate(flags), isTrue);
    });
  });
}