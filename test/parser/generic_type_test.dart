import 'package:test/test.dart';
import 'package:micro_panda/src/cli/builder.dart';
import 'package:micro_panda/src/cli/project.dart';
import 'package:micro_panda/src/ast/module.dart';
import 'package:micro_panda/src/parser/parser.dart';
import 'package:micro_panda/src/token/position.dart';

Module _parse(String src) {
  final sf = SourceFile('test', 0, src.length);
  return Parser(sf, src, {}).parseModule('test');
}

void main() {
  test('nested generic type argument is rejected', () {
    expect(
      () => _parse('var x: ArrayList<ArrayList<i32>>'),
      throwsA(isA<CompileException>()),
    );
  });

  test('nested generic behind ref is rejected', () {
    expect(
      () => _parse('var x: ArrayList<&ArrayList<i32>>'),
      throwsA(isA<CompileException>()),
    );
  });

  test('single generic type argument is accepted', () {
    expect(
      () => _parse('var x: ArrayList<i32>'),
      returnsNormally,
    );
  });

  test('build collection_test through full pipeline', () async {
    final projDir = '/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std';
    final proj = Project.load(projDir);
    final target = Target(
      name: 'collection_test',
      entry: 'collection_test',
      flags: ['HOSTED'],
      cc: 'gcc',
      cflags: ['-O0'],
      out: '/tmp/mpd_test_out',
      output: '/tmp/mpd_test_out/collection_test',
    );
    try {
      final cFile = Builder(proj, target, verbose: true).gen();
      print('C file: $cFile');
      expect(cFile, isNotNull);
    } catch (e) {
      print('ERROR: $e');
      rethrow;
    }
  });
}
