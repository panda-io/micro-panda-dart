import 'package:test/test.dart';
import 'package:micro_panda/src/token/position.dart'; 

void main() {
  group('SourceFile Location Tests', () {
    late SourceFile file;
    const String content = "abc\ndefg\nhi";

    setUp(() {
      file = SourceFile("test.mpd", 0, content.length);

      file.addLine(4);
      file.addLine(9);
    });

    test('Should return correct line and column for first line', () {
      final (line, column) = file.getLocation(0); // 'a'
      expect(line, equals(1));
      expect(column, equals(1));

      final (line2, column2) = file.getLocation(3); // '\n'
      expect(line2, equals(1));
      expect(column2, equals(4));
    });

    test('Should return correct line and column for middle line', () {
      final (line, column) = file.getLocation(4); // 'd'
      expect(line, equals(2));
      expect(column, equals(1));

      final (line2, column2) = file.getLocation(8); // '\n'
      expect(line2, equals(2));
      expect(column2, equals(5));
    });

    test('Should handle the last character of the file', () {
      final (line, column) = file.getLocation(10); // 'i'
      expect(line, equals(3));
      expect(column, equals(2));
    });

    test('Should handle out of bounds gracefully', () {
      final (line, column) = file.getLocation(100);
      expect(line, equals(0));
      expect(column, equals(0));
    });
  });

  group('SourceSet & Global Mapping Tests', () {
    late SourceSet sourceSet;

    setUp(() {
      sourceSet = SourceSet();
    });

    test('Should manage multiple files and global offsets', () {
      final file1 = sourceSet.addFile("file1.mpd", 10);
      final file2 = sourceSet.addFile("file2.mpd", 20);

      // file1 base is 0, file2 base is 11 (10 + 1 separator)
      expect(file1.baseOffset, equals(0));
      expect(file2.baseOffset, equals(11));

      final foundFile = sourceSet.getFile(12);
      expect(foundFile?.name, equals("file2.mpd"));

      final pos = sourceSet.getPosition(12);
      expect(pos?.offset, equals(1)); // 12 - 11 = 1
    });

    test('Should throw error when adding duplicate file names', () {
      sourceSet.addFile("dup.mp", 10);
      expect(() => sourceSet.addFile("dup.mp", 5), throwsArgumentError);
    });
  });

  group('Position Formatting', () {
    test('ToString should format correctly', () {
      final file = SourceFile("main.mpd", 0, 10);
      file.addLine(5);
      final pos = Position(file, 6);
      
      expect(pos.toString(), equals("main.mpd:2:2"));
    });
  });
}