import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:micro_panda/src/cli/builder.dart';
import 'package:micro_panda/src/cli/project.dart';

const _usage = '''
micro-panda compiler

Usage:
  mpd <command> [target] [options]

Commands:
  gen   [target]   Generate C only (no compilation)
  build [target]   Generate C then compile to executable
  run   <target>   Build then run the target executable
  test  [file]     Compile and run test files (*_test.mpd)
  clean            Delete generated C files and binaries

Options:
  -v, --verbose    Print detailed build steps
  -h, --help       Show this help

Examples:
  mpd gen                   Generate C for all targets
  mpd gen firmware          Generate C for a specific target
  mpd build                 Build all targets
  mpd build firmware        Build a specific target
  mpd run main              Build and run the main target
  mpd test                  Run all *_test.mpd files
  mpd test main_test.mpd    Run a specific test file
  mpd clean
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    stdout.write(_usage);
    return;
  }

  final verbose = args.contains('-v') || args.contains('--verbose');
  final cleanArgs = args.where((a) => !a.startsWith('-')).toList();

  final command = cleanArgs.isNotEmpty ? cleanArgs[0] : '';
  final targetArg = cleanArgs.length > 1 ? cleanArgs[1] : null;

  switch (command) {
    case 'gen':
      await _cmdGen(targetArg, verbose: verbose);
    case 'build':
      await _cmdBuild(targetArg, verbose: verbose);
    case 'run':
      await _cmdRun(targetArg, verbose: verbose);
    case 'test':
      await _cmdTest(targetArg, verbose: verbose);
    case 'clean':
      await _cmdClean(verbose: verbose);
    default:
      stderr.writeln('Unknown command: "$command"');
      stderr.writeln('Run "mpd --help" for usage.');
      exit(1);
  }
}

// ── commands ─────────────────────────────────────────────────────────────────

Future<void> _cmdGen(String? targetName, {required bool verbose}) async {
  final project = _loadProject();
  final targets = _resolveTargets(project, targetName);

  var allOk = true;
  for (final target in targets) {
    final file = Builder(project, target, verbose: verbose).gen();
    if (file == null) {
      allOk = false;
    } else {
      stdout.writeln('Generated: ${file.path}');
    }
  }
  exit(allOk ? 0 : 1);
}

Future<void> _cmdBuild(String? targetName, {required bool verbose}) async {
  final project = _loadProject();
  final targets = _resolveTargets(project, targetName);

  var allOk = true;
  for (final target in targets) {
    final ok = await Builder(project, target, verbose: verbose).build();
    if (!ok) allOk = false;
  }

  exit(allOk ? 0 : 1);
}

Future<void> _cmdRun(String? targetName, {required bool verbose}) async {
  if (targetName == null) {
    stderr.writeln('error: "run" requires a target name.');
    exit(1);
  }

  final project = _loadProject();
  final targets = _resolveTargets(project, targetName);
  final target = targets.first;

  final ok = await Builder(project, target, verbose: verbose).build();
  if (!ok) exit(1);

  // Determine output path.
  final output = target.output != null
      ? target.output!
      : 'bin/${target.name}';

  stdout.writeln('Running $output...');
  final result = await Process.run(output, [], workingDirectory: project.rootDir);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}

Future<void> _cmdTest(String? fileArg, {required bool verbose}) async {
  final project = _loadProject();

  // Discover test files: explicit arg or all *_test.mpd in src/.
  final testFiles = <File>[];
  if (fileArg != null) {
    // Accept "main_test.mpd", "main_test", or a path.
    var path = fileArg.endsWith('.mpd') ? fileArg : '$fileArg.mpd';
    if (!p.isAbsolute(path)) path = p.join(project.src, path);
    final f = File(path);
    if (!f.existsSync()) {
      stderr.writeln('error: test file not found: ${f.path}');
      exit(1);
    }
    testFiles.add(f);
  } else {
    final srcDir = Directory(project.src);
    if (srcDir.existsSync()) {
      testFiles.addAll(srcDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('_test.mpd')));
    }
  }

  if (testFiles.isEmpty) {
    stdout.writeln('No test files found.');
    exit(0);
  }

  // Reference target for cc/cflags — use first defined target as template.
  final refTarget = project.targets.values.firstOrNull;

  var allPassed = true;
  for (final file in testFiles) {
    final name = p.basenameWithoutExtension(file.path);
    final testTarget = Target(
      name: name,
      entry: p.withoutExtension(
          p.relative(file.path, from: project.src)),
      flags: [
        ...?refTarget?.flags.where((f) => f != 'RELEASE' && f != 'DEBUG'),
        'STDC_HOSTED',
      ],
      cc: refTarget?.cc ?? 'gcc',
      ccPath: refTarget?.ccPath,
      cflags: refTarget?.cflags ?? ['-O0'],
      out: p.join(project.rootDir, '.micro-panda', 'test'),
      output: p.join('.micro-panda', 'test', name),
    );

    final ok = await Builder(project, testTarget, verbose: verbose).build();
    if (!ok) { allPassed = false; continue; }

    final binary = p.join(project.rootDir, '.micro-panda', 'test', name);
    final result = await Process.run(binary, [],
        workingDirectory: project.rootDir);
    stdout.write(result.stdout);
    if (result.stderr.toString().isNotEmpty) stderr.write(result.stderr);
    if (result.exitCode != 0) allPassed = false;
  }

  exit(allPassed ? 0 : 1);
}

Future<void> _cmdClean({required bool verbose}) async {
  final project = _loadProject();

  _deleteDir(project.out, project.rootDir, verbose: verbose);

  // Also clean per-target out dirs and bin/.
  for (final target in project.targets.values) {
    if (target.out != null) {
      _deleteDir(target.out!, project.rootDir, verbose: verbose);
    }
  }
  _deleteDir('bin', project.rootDir, verbose: verbose);

  stdout.writeln('Cleaned.');
}

// ── helpers ───────────────────────────────────────────────────────────────────

Project _loadProject() {
  try {
    return Project.load();
  } catch (e) {
    stderr.writeln('error: $e');
    exit(1);
  }
}

List<Target> _resolveTargets(Project project, String? name) {
  if (project.targets.isEmpty) {
    stderr.writeln('error: no targets defined in mpd.yaml');
    exit(1);
  }
  if (name == null) return project.targets.values.toList();
  final target = project.targets[name];
  if (target == null) {
    stderr.writeln('error: unknown target "$name". '
        'Available: ${project.targets.keys.join(', ')}');
    exit(1);
  }
  return [target];
}

void _deleteDir(String rel, String root, {required bool verbose}) {
  final dir = Directory('$root/$rel');
  if (dir.existsSync()) {
    if (verbose) stdout.writeln('  Deleting ${dir.path}');
    dir.deleteSync(recursive: true);
  }
}
