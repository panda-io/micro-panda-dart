import 'package:test/test.dart';
import 'package:micro_panda/src/cli/builder.dart';
import 'package:micro_panda/src/cli/project.dart';

void main() {
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
