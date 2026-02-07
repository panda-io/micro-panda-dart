import 'package:test/test.dart';
import 'package:micro_panda/src/token/token_type.dart'; 

void main() {
  group('Token Logic Tests', () {
    test('Keyword identification', () {
      // Test if 'if' is identified as a keyword
      expect(TokenType.fromString('if').isKeyword, isTrue);
      // Test if an arbitrary identifier is NOT a keyword
      expect(TokenType.fromString('myVar').isKeyword, isFalse);
    });

    test('Operator precedence', () {
      // Multiplication should have higher precedence than addition
      expect(TokenType.mul.precedence > TokenType.plus.precedence, isTrue);
      // Assignments should have very low precedence
      expect(TokenType.plusAssign.precedence, equals(1));
    });

    test('Range boundaries', () {
      // literalBegin and literalEnd themselves should not be considered literals
      expect(TokenType.literalBegin.isLiteral, isFalse);
      expect(TokenType.intLiteral.isLiteral, isTrue);
    });

    test('String to Token mapping', () {
      expect(TokenType.fromString('..'), TokenType.cascade);
      expect(TokenType.fromString('i32'), TokenType.typeInt32);
      expect(TokenType.fromString('true'), TokenType.identifier); // We handle booleans in the Scanner usually
    });
  });
}