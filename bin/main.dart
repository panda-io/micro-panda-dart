import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:micro_panda/src/cli/builder.dart';
import 'package:micro_panda/src/cli/dep_manager.dart';
import 'package:micro_panda/src/cli/project.dart';
import 'package:micro_panda/src/cli/templates.dart';
import 'package:micro_panda/src/lsp/server.dart';

const _usage = '''
micro-panda compiler

Usage:
  mpd <command> [args] [options]

Commands:
  init   [name]              Create mpd.yaml + src/main.mpd (hosted-debug template)
  gen    [target]            Generate C only (no compilation)
  build  [target]            Generate C then compile to executable
  run    <target>            Build then run the target executable
  test   [file]              Compile and run test files (*_test.mpd)
  clean                      Delete generated C files and binaries
  update                     Re-fetch all git dependencies
  lsp                        Start Language Server Protocol server (stdin/stdout)
  target add  <name> <tpl>  Add a target from a template
  target remove <name>       Remove a target from mpd.yaml
  target list                List available target templates

Options:
  -C <dir>         Project directory (where mpd.yaml lives). Defaults to cwd.
  -v, --verbose    Print detailed build steps
  -h, --help       Show this help

Examples:
  mpd init                      Create a new project in the current directory
  mpd init myapp                Create a new project named "myapp"
  mpd gen                       Generate C for all targets
  mpd gen firmware              Generate C for a specific target
  mpd build                     Build all targets
  mpd run main                  Build and run the main target
  mpd test                      Run all *_test.mpd files
  mpd -C /path/to/project gen   Operate on a specific project directory
  mpd target add esp32 esp32-release
  mpd target remove esp32
  mpd target list
''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    stdout.write(_usage);
    return;
  }

  final verbose = args.contains('-v') || args.contains('--verbose');

  // Extract -C <dir> option.
  String? projectDir;
  final mutableArgs = args.toList();
  final cIdx = mutableArgs.indexOf('-C');
  if (cIdx != -1 && cIdx + 1 < mutableArgs.length) {
    projectDir = mutableArgs[cIdx + 1];
    mutableArgs.removeRange(cIdx, cIdx + 2);
  }

  final cleanArgs = mutableArgs.where((a) => !a.startsWith('-')).toList();

  final command = cleanArgs.isNotEmpty ? cleanArgs[0] : '';
  final targetArg = cleanArgs.length > 1 ? cleanArgs[1] : null;

  switch (command) {
    case 'init':
      _cmdInit(targetArg, projectDir: projectDir);
    case 'gen':
      await _cmdGen(targetArg, verbose: verbose, projectDir: projectDir);
    case 'build':
      await _cmdBuild(targetArg, verbose: verbose, projectDir: projectDir);
    case 'run':
      await _cmdRun(targetArg, verbose: verbose, projectDir: projectDir);
    case 'test':
      await _cmdTest(targetArg, verbose: verbose, projectDir: projectDir);
    case 'clean':
      await _cmdClean(verbose: verbose, projectDir: projectDir);
    case 'update':
      await _cmdUpdate(projectDir: projectDir);
    case 'lsp':
      await LspServer().run();
    case 'target':
      final sub = cleanArgs.length > 1 ? cleanArgs[1] : '';
      final arg1 = cleanArgs.length > 2 ? cleanArgs[2] : null;
      final arg2 = cleanArgs.length > 3 ? cleanArgs[3] : null;
      switch (sub) {
        case 'add':
          if (arg1 == null || arg2 == null) {
            stderr.writeln('error: usage: mpd target add <name> <template>');
            exit(1);
          }
          _cmdTargetAdd(arg1, arg2, projectDir: projectDir);
        case 'remove':
          if (arg1 == null) {
            stderr.writeln('error: usage: mpd target remove <name>');
            exit(1);
          }
          _cmdTargetRemove(arg1, projectDir: projectDir);
        case 'list':
          _cmdTargetList();
        default:
          stderr.writeln('Unknown target subcommand: "$sub"');
          stderr.writeln('Run "mpd --help" for usage.');
          exit(1);
      }
    default:
      stderr.writeln('Unknown command: "$command"');
      stderr.writeln('Run "mpd --help" for usage.');
      exit(1);
  }
}

// ── commands ─────────────────────────────────────────────────────────────────

Future<void> _cmdGen(String? targetName, {required bool verbose, String? projectDir}) async {
  final project = _loadProject(projectDir);
  final targets = _resolveTargets(project, targetName);

  var allOk = true;
  for (final target in targets) {
    final file = await Builder(project, target, verbose: verbose).gen();
    if (file == null) {
      allOk = false;
    } else {
      stdout.writeln('Generated: ${file.path}');
    }
  }
  exit(allOk ? 0 : 1);
}

Future<void> _cmdBuild(String? targetName, {required bool verbose, String? projectDir}) async {
  final project = _loadProject(projectDir);
  final targets = _resolveTargets(project, targetName);

  var allOk = true;
  for (final target in targets) {
    final ok = await Builder(project, target, verbose: verbose).build();
    if (!ok) allOk = false;
  }

  exit(allOk ? 0 : 1);
}

Future<void> _cmdRun(String? targetName, {required bool verbose, String? projectDir}) async {
  if (targetName == null) {
    stderr.writeln('error: "run" requires a target name.');
    exit(1);
  }

  final project = _loadProject(projectDir);
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

Future<void> _cmdTest(String? targetName, {required bool verbose, String? projectDir}) async {
  final project = _loadProject(projectDir);

  // If the argument looks like a file path, run just that single test file.
  if (targetName != null && targetName.endsWith('.mpd')) {
    final file = File(p.isAbsolute(targetName) ? targetName : p.join(project.rootDir, targetName));
    if (!file.existsSync()) {
      stderr.writeln('error: test file not found: ${file.path}');
      exit(1);
    }
    // Find the target whose test dir contains this file.
    Target? owner;
    for (final t in project.targets.values) {
      if (t.test == null) continue;
      final testDir = project.testDirFor(t)!;
      if (p.isWithin(testDir, file.path)) { owner = t; break; }
    }
    if (owner == null) {
      stderr.writeln('error: "$targetName" is not inside any target\'s test directory');
      exit(1);
    }
    final testDir = project.testDirFor(owner)!;
    final name = p.basenameWithoutExtension(file.path);
    final testTarget = Target(
      name: name,
      entry: p.withoutExtension(p.relative(file.path, from: testDir))
          .replaceAll(p.separator, '.'),
      type: TargetType.bin,
      flags: owner.flags,
      cc: owner.cc ?? CcConfig(flags: ['-g', '-O0', '-w']),
      src: owner.src,
      test: owner.test,
      out: p.join(project.rootDir, '.micro-panda', 'test', '$name.c'),
      output: p.join('.micro-panda', 'test', name),
    );
    final ok = await Builder(project, testTarget, verbose: verbose).build();
    if (!ok) exit(1);
    final binary = p.join(project.rootDir, '.micro-panda', 'test', name);
    final result = await Process.run(binary, [], workingDirectory: project.rootDir);
    stdout.write(result.stdout);
    if (result.stderr.toString().isNotEmpty) stderr.write(result.stderr);
    exit(result.exitCode);
  }

  // Resolve which targets to test.
  final List<Target> targets;
  if (targetName != null) {
    final t = project.targets[targetName];
    if (t == null) {
      stderr.writeln('error: unknown target "$targetName". '
          'Available: ${project.targets.keys.join(', ')}');
      exit(1);
    }
    if (t.test == null) {
      stderr.writeln('error: target "$targetName" has no test: folder defined');
      exit(1);
    }
    targets = [t];
  } else {
    targets = project.targets.values.where((t) => t.test != null).toList();
    if (targets.isEmpty) {
      stdout.writeln('No targets with test: defined.');
      exit(0);
    }
  }

  var allPassed = true;
  for (final target in targets) {
    final testDir = Directory(project.testDirFor(target)!);
    if (!testDir.existsSync()) {
      stdout.writeln('Skipping "${target.name}": test directory not found (${testDir.path})');
      continue;
    }

    final testFiles = testDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_test.mpd'))
        .toList();

    if (testFiles.isEmpty) {
      stdout.writeln('No *_test.mpd files in ${testDir.path}');
      continue;
    }

    for (final file in testFiles) {
      final name = p.basenameWithoutExtension(file.path);
      final testTarget = Target(
        name: name,
        entry: p.withoutExtension(p.relative(file.path, from: testDir.path))
            .replaceAll(p.separator, '.'),
        type: TargetType.bin,
        flags: target.flags,
        cc: target.cc ?? CcConfig(flags: ['-g', '-O0', '-w']),
        src: target.src,
        test: target.test,
        out: p.join(project.rootDir, '.micro-panda', 'test', '$name.c'),
        output: p.join('.micro-panda', 'test', name),
      );

      final ok = await Builder(project, testTarget, verbose: verbose).build();
      if (!ok) { allPassed = false; continue; }

      final binary = p.join(project.rootDir, '.micro-panda', 'test', name);
      final result = await Process.run(binary, [], workingDirectory: project.rootDir);
      stdout.write(result.stdout);
      if (result.stderr.toString().isNotEmpty) stderr.write(result.stderr);
      if (result.exitCode != 0) allPassed = false;
    }
  }

  exit(allPassed ? 0 : 1);
}

Future<void> _cmdClean({required bool verbose, String? projectDir}) async {
  final project = _loadProject(projectDir);

  // Delete .micro-panda/ (stdlib cache, test build artifacts).
  _deleteDir('.micro-panda', project.rootDir, verbose: verbose);

  // Delete default C output directory.
  _deleteDir('out', project.rootDir, verbose: verbose);

  // Delete default binary output directory.
  _deleteDir('bin', project.rootDir, verbose: verbose);

  // Delete per-target custom output paths from mpd.yaml.
  for (final target in project.targets.values) {
    if (target.out != null) {
      _deletePath(target.out!, project.rootDir, verbose: verbose);
    }
    if (target.output != null) {
      _deletePath(target.output!, project.rootDir, verbose: verbose);
    }
  }

  stdout.writeln('Cleaned.');
}

Future<void> _cmdUpdate({String? projectDir}) async {
  final project = _loadProject(projectDir);
  try {
    if (project.deps.isNotEmpty) {
      final infos = await DepManager(project).ensureDeps(forceUpdate: true);
      stdout.writeln('Updated ${infos.length} ${infos.length == 1 ? 'dependency' : 'dependencies'}.');
    }
    Builder.updateStd(project.rootDir);
    stdout.writeln('Updated std (${Builder.stdlibHash}).');
  } catch (e) {
    stderr.writeln('error: $e');
    exit(1);
  }
}

// ── project scaffold ─────────────────────────────────────────────────────────

void _cmdInit(String? nameArg, {String? projectDir}) {
  final dir = projectDir ?? Directory.current.path;
  final name = nameArg ?? p.basename(dir);

  final yamlFile = File(p.join(dir, 'mpd.yaml'));
  if (yamlFile.existsSync()) {
    stderr.writeln('error: mpd.yaml already exists in $dir');
    exit(1);
  }

  final template = kTemplates[kInitTemplate]!;
  final yaml = 'name: $name\nversion: 0.1.0\n\ntargets:\n${template.render(kInitEntryModule)}';
  yamlFile.writeAsStringSync(yaml);

  final srcDir = Directory(p.join(dir, 'src'));
  srcDir.createSync(recursive: true);
  final mainFile = File(p.join(srcDir.path, 'main.mpd'));
  if (!mainFile.existsSync()) mainFile.writeAsStringSync(kInitMainMpd);

  stdout.writeln('Created mpd.yaml');
  stdout.writeln('Created src/main.mpd');
  stdout.writeln('Run "mpd build" to compile.');
}

// ── target management ─────────────────────────────────────────────────────────

void _cmdTargetAdd(String name, String templateId, {String? projectDir}) {
  final template = kTemplates[templateId];
  if (template == null) {
    stderr.writeln('error: unknown template "$templateId"');
    stderr.writeln('Run "mpd target list" to see available templates.');
    exit(1);
  }

  final project = _loadProject(projectDir);
  if (project.targets.containsKey(name)) {
    stderr.writeln('error: target "$name" already exists in mpd.yaml');
    exit(1);
  }

  final yamlFile = File(p.join(project.rootDir, 'mpd.yaml'));
  final content = yamlFile.readAsStringSync();
  final block = template.render(name);
  final newContent = content.endsWith('\n') ? '$content$block' : '$content\n$block';
  yamlFile.writeAsStringSync(newContent);

  stdout.writeln('Added target "$name" using template "$templateId".');
}

void _cmdTargetRemove(String name, {String? projectDir}) {
  final project = _loadProject(projectDir);
  if (!project.targets.containsKey(name)) {
    stderr.writeln('error: target "$name" not found in mpd.yaml');
    exit(1);
  }

  final yamlFile = File(p.join(project.rootDir, 'mpd.yaml'));
  final lines = yamlFile.readAsLinesSync();

  // Find the target block: starts at `  <name>:`, ends before the next `  \w` line or EOF.
  final startRe = RegExp('^  ${RegExp.escape(name)}:');
  final nextRe  = RegExp(r'^  \w');

  int? start;
  int end = lines.length;
  for (var i = 0; i < lines.length; i++) {
    if (start == null) {
      if (startRe.hasMatch(lines[i])) start = i;
    } else if (nextRe.hasMatch(lines[i])) {
      end = i;
      break;
    }
  }

  if (start == null) {
    stderr.writeln('error: could not locate target "$name" block in mpd.yaml');
    exit(1);
  }

  lines.removeRange(start, end);

  // Drop any trailing blank lines left at end of targets section.
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }

  yamlFile.writeAsStringSync('${lines.join('\n')}\n');
  stdout.writeln('Removed target "$name".');
}

void _cmdTargetList() {
  stdout.writeln('Available target templates:\n');
  for (final e in kTemplates.entries) {
    stdout.writeln('  ${e.key.padRight(18)} ${e.value.description}');
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────

Project _loadProject([String? projectDir]) {
  try {
    return Project.load(projectDir);
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
  final path = p.isAbsolute(rel) ? rel : p.join(root, rel);
  final dir = Directory(path);
  if (dir.existsSync()) {
    if (verbose) stdout.writeln('  Deleting $path');
    dir.deleteSync(recursive: true);
  }
}

/// Delete a file or directory at [rel] (relative to [root], or absolute).
void _deletePath(String rel, String root, {required bool verbose}) {
  final path = p.isAbsolute(rel) ? rel : p.join(root, rel);
  final file = File(path);
  if (file.existsSync()) {
    if (verbose) stdout.writeln('  Deleting $path');
    file.deleteSync();
    return;
  }
  final dir = Directory(path);
  if (dir.existsSync()) {
    if (verbose) stdout.writeln('  Deleting $path');
    dir.deleteSync(recursive: true);
  }
}
