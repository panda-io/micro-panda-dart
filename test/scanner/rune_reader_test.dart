import 'package:test/test.dart';
import 'package:micro_panda/src/scanner/rune_reader.dart';
import 'package:micro_panda/src/token/position.dart';

void main() {
  group('RuneReader Tests', () {
    late SourceFile file;
    late RuneReader reader;
    const String source = "abc\n123";

    setUp(() {
      file = SourceFile("test.mpd", 0, source.length);
      reader = RuneReader(file, source);
    });

    test('consume reads characters sequentially', () {
      expect(reader.consume(), equals(97)); // 'a'
      expect(reader.consume(), equals(98)); // 'b'
      expect(reader.consume(), equals(99)); // 'c'
    });

    test('peek returns current character without advancing', () {
      expect(reader.peek(), equals(97)); // 'a'
      expect(reader.offset, equals(0));
      expect(reader.consume(), equals(97));
      expect(reader.peek(), equals(98)); // 'b'
    });

    test('back reverses position', () {
      reader.consume(); // 'a'
      reader.consume(); // 'b'
      expect(reader.offset, equals(2));
      
      reader.back();
      expect(reader.offset, equals(1));
      expect(reader.peek(), equals(98)); // 'b'

      reader.back();
      expect(reader.offset, equals(0));
      expect(reader.peek(), equals(97)); // 'a'
    });

    test('back with steps', () {
      reader.consume();
      reader.consume();
      reader.consume();
      expect(reader.offset, equals(3));
      
      reader.back(2);
      expect(reader.offset, equals(1));
      expect(reader.peek(), equals(98)); // 'b'
    });

    test('cutIn and cutOut extract substrings', () {
      reader.consume(); // 'a'
      reader.cutIn(); // Start at 'b' (offset 1)
      
      reader.consume(); // 'b'
      reader.consume(); // 'c'
      
      expect(reader.cutOut(), equals("bc"));
    });

    test('consume handles newlines and updates file lines', () {
      // "abc\n123"
      reader.consume(); // a
      reader.consume(); // b
      reader.consume(); // c
      
      // Before newline, line count is 1 (default)
      expect(file.lineCount, equals(1));
      
      reader.consume(); // \n
      
      // After newline, line count should increase
      expect(file.lineCount, equals(2));
    });

    test('EOF handling', () {
      final emptyReader = RuneReader(file, "");
      expect(emptyReader.isAtEnd, isTrue);
      expect(emptyReader.peek(), equals(RuneReader.eof));
      expect(emptyReader.consume(), equals(RuneReader.eof));
    });
  });

  group('RuneExt Tests', () {
    test('isLetter', () {
      expect('a'.codeUnitAt(0).isLetter, isTrue);
      expect('Z'.codeUnitAt(0).isLetter, isTrue);
      expect('_'.codeUnitAt(0).isLetter, isTrue);
      expect('1'.codeUnitAt(0).isLetter, isFalse);
      expect('.'.codeUnitAt(0).isLetter, isFalse);
    });

    test('isDecimal', () {
      expect('0'.codeUnitAt(0).isDecimal, isTrue);
      expect('9'.codeUnitAt(0).isDecimal, isTrue);
      expect('a'.codeUnitAt(0).isDecimal, isFalse);
    });

    test('toLower', () {
      expect('A'.codeUnitAt(0).toLower(), equals('a'.codeUnitAt(0)));
      expect('z'.codeUnitAt(0).toLower(), equals('z'.codeUnitAt(0)));
      expect('1'.codeUnitAt(0).toLower(), equals('1'.codeUnitAt(0)));
    });

    test('digitValue', () {
      expect('0'.codeUnitAt(0).digitValue, equals(0));
      expect('9'.codeUnitAt(0).digitValue, equals(9));
      expect('a'.codeUnitAt(0).digitValue, equals(10));
      expect('f'.codeUnitAt(0).digitValue, equals(15));
      expect('A'.codeUnitAt(0).digitValue, equals(10));
      expect('F'.codeUnitAt(0).digitValue, equals(15));
      expect('g'.codeUnitAt(0).digitValue, equals(16)); // Out of hex range
    });
  });
}