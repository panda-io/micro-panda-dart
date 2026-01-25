import 'package:test/test.dart';
// Replace with your actual project path
import 'package:micro_panda/src/token/token.dart'; 

void main() {
  group('Token Logic Tests', () {
    test('Keyword identification', () {
      // Test if 'if' is identified as a keyword
      expect(Token.fromString('if').isKeyword, isTrue);
      // Test if an arbitrary identifier is NOT a keyword
      expect(Token.fromString('myVar').isKeyword, isFalse);
    });

    test('Operator precedence', () {
      // Multiplication should have higher precedence than addition
      expect(Token.mul.precedence > Token.plus.precedence, isTrue);
      // Assignments should have very low precedence
      expect(Token.plusAssign.precedence, equals(1));
    });

    test('Range boundaries', () {
      // literalBegin and literalEnd themselves should not be considered literals
      expect(Token.literalBegin.isLiteral, isFalse);
      expect(Token.intLiteral.isLiteral, isTrue);
    });

    test('String to Token mapping', () {
      expect(Token.fromString('..'), Token.cascade);
      expect(Token.fromString('i32'), Token.typeInt32);
      expect(Token.fromString('true'), Token.identifier); // We handle booleans in the Scanner usually
    });
  });
}