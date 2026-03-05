import 'dart:io';
import 'package:path/path.dart' as p;

import '../ast/module.dart';
import '../generator/c/generator.dart';
import '../parser/parser.dart';
import '../token/position.dart';
import '../validator/validator.dart';
import 'project.dart';

/// Drives the full build pipeline for a single [Target].
class Builder {
  final Project project;
  final Target target;
  final bool verbose;

  Builder(this.project, this.target, {this.verbose = false});

  /// Generate C only (no compilation). Returns the written file path, or null on error.
  File? gen() {
    _log('Generating C for target "${target.name}"...');
    final modules = _parseModules();
    if (modules == null) return null;
    if (!_validate(modules)) return null;
    final cCode = _generateC(modules);
    final cFile = _writeCFile(cCode);
    if (cFile != null) _log('Done: ${p.relative(cFile.path, from: project.rootDir)}');
    return cFile;
  }

  /// Run the full pipeline: discover → parse → validate → generate C → compile/build.
  /// Returns true on success.
  Future<bool> build() async {
    _log('Building target "${target.name}"...');

    // 1. Discover all .mpd source files reachable from the entry module.
    final modules = _parseModules();
    if (modules == null) return false;

    // 2. Validate.
    if (!_validate(modules)) return false;

    // 3. Generate C.
    final cCode = _generateC(modules);

    // 4. Write generated C to output directory.
    final cFile = _writeCFile(cCode);
    if (cFile == null) return false;

    // 5. Compile or delegate to custom build system.
    if (target.isCustomMode) {
      return await _runBuildCmd();
    } else {
      return await _compile(cFile);
    }
  }

  // ── step 1: parse ─────────────────────────────────────────────────────────

  List<Module>? _parseModules() {
    final entryFile = _resolveEntry();
    if (!entryFile.existsSync()) {
      _error('Entry file not found: ${entryFile.path}');
      return null;
    }

    final visited = <String>{};
    final modules = <Module>[];
    final queue = <File>[entryFile];

    while (queue.isNotEmpty) {
      final file = queue.removeAt(0);
      final absPath = p.normalize(file.absolute.path);
      if (visited.contains(absPath)) continue;
      visited.add(absPath);

      _log('  Parsing ${p.relative(absPath, from: project.rootDir)}');

      try {
        final source = file.readAsStringSync();
        final sf = SourceFile(absPath, 0, source.length);
        final modulePath = _modulePathFor(absPath);
        final flags = Set<String>.from(target.flags);
        final module = Parser(sf, source, flags).parseModule(modulePath);
        modules.add(module);

        // Enqueue imported modules.
        for (final imp in module.imports) {
          final importedFile = _resolveImport(imp.path);
          if (importedFile != null) queue.add(importedFile);
        }
      } catch (e) {
        _error('Parse error in ${p.relative(absPath, from: project.rootDir)}: $e');
        return null;
      }
    }

    return modules;
  }

  File _resolveEntry() {
    // Entry can be a module path like "firmware/main" or just "main".
    final rel = '${target.entry.replaceAll('.', p.separator)}.mpd';
    return File(p.join(project.src, rel));
  }

  File? _resolveImport(String importPath) {
    final rel = '${importPath.replaceAll('.', p.separator)}.mpd';
    final file = File(p.join(project.src, rel));
    return file.existsSync() ? file : null;
  }

  String _modulePathFor(String absPath) {
    final rel = p.relative(absPath, from: project.src);
    return p.withoutExtension(rel).replaceAll(p.separator, '.');
  }

  // ── step 2: validate ──────────────────────────────────────────────────────

  bool _validate(List<Module> modules) {
    _log('  Validating...');
    final errors = Validator().validate(modules);
    for (final e in errors) {
      _error(e.toString());
    }
    return errors.isEmpty;
  }

  // ── step 3: generate C ────────────────────────────────────────────────────

  String _generateC(List<Module> modules) {
    _log('  Generating C...');
    return CGenerator().generate(modules);
  }

  // ── step 3: write C file ──────────────────────────────────────────────────

  File? _writeCFile(String cCode) {
    try {
      final outDir = Directory(project.outDirFor(target));
      if (!outDir.existsSync()) outDir.createSync(recursive: true);

      final cFile = File(p.join(outDir.path, '${target.name}.c'));
      cFile.writeAsStringSync(cCode);
      _log('  Written ${p.relative(cFile.path, from: project.rootDir)}');
      return cFile;
    } catch (e) {
      _error('Failed to write C file: $e');
      return null;
    }
  }

  // ── step 4a: simple mode — invoke C compiler ──────────────────────────────

  Future<bool> _compile(File cFile) async {
    final cc = target.ccBin;
    final output = _resolveOutput();

    // Ensure output directory exists.
    final outDir = Directory(p.dirname(output));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final args = [
      ...target.cflags,
      cFile.path,
      '-o', output,
    ];

    _log('  Compiling: $cc ${args.join(' ')}');
    final result = await Process.run(cc, args, workingDirectory: project.rootDir);

    if (result.stdout.toString().isNotEmpty) stdout.write(result.stdout);
    if (result.stderr.toString().isNotEmpty) stderr.write(result.stderr);

    if (result.exitCode != 0) {
      _error('Compilation failed (exit ${result.exitCode})');
      return false;
    }

    _log('  Output: $output');
    return true;
  }

  // ── step 4b: custom mode — run external build system ─────────────────────

  Future<bool> _runBuildCmd() async {
    final cmd = target.buildCmd!;
    _log('  Running: $cmd');

    // Split into executable + arguments respecting quoted strings.
    final parts = _splitCommand(cmd);
    final result = await Process.run(
      parts.first,
      parts.skip(1).toList(),
      workingDirectory: project.rootDir,
      runInShell: true,
    );

    if (result.stdout.toString().isNotEmpty) stdout.write(result.stdout);
    if (result.stderr.toString().isNotEmpty) stderr.write(result.stderr);

    if (result.exitCode != 0) {
      _error('Build command failed (exit ${result.exitCode})');
      return false;
    }
    return true;
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  String _resolveOutput() {
    if (target.output != null) return p.join(project.rootDir, target.output!);
    final binDir = p.join(project.rootDir, 'bin');
    return p.join(binDir, target.name);
  }

  /// Naive command splitter: splits on whitespace, respects single/double quotes.
  List<String> _splitCommand(String cmd) {
    final parts = <String>[];
    final buf = StringBuffer();
    String? quote;
    for (final ch in cmd.split('')) {
      if (quote != null) {
        if (ch == quote) {
          quote = null;
        } else {
          buf.write(ch);
        }
      } else if (ch == '"' || ch == "'") {
        quote = ch;
      } else if (ch == ' ') {
        if (buf.isNotEmpty) {
          parts.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) parts.add(buf.toString());
    return parts;
  }

  void _log(String msg) {
    if (verbose) stdout.writeln(msg);
  }

  void _error(String msg) => stderr.writeln('error: $msg');
}
