import 'dart:io';
import 'package:path/path.dart' as p;

import '../ast/context.dart' show ValidationError;
import '../ast/module.dart';
import '../ast/type/type.dart';
import '../generator/generator.dart';
import '../parser/parser.dart';
import '../stdlib_embedded.dart';
import '../token/position.dart';
import '../validator/validator.dart';
import 'config_loader.dart' show parseConfigEntries, buildConfigData;
import 'dep_manager.dart';
import 'project.dart';

/// Drives the full build pipeline for a single [Target].
class Builder {
  final Project project;
  final Target target;
  final bool verbose;

  /// Config vars loaded from [Target.config]; populated by [_parseModules].
  Map<String, Type?> _configVars = {};

  /// Fetched dep info; populated by [_fetchDeps] before parsing.
  Map<String, DepInfo> _depInfos = {};

  late final DepManager _depManager = DepManager(project);

  Builder(this.project, this.target, {this.verbose = false});

  /// Generate C only (no compilation). Returns the written file path, or null on error.
  Future<File?> gen() async {
    _log('Generating C for target "${target.name}"...');
    await _fetchDeps();
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
    await _fetchDeps();

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

    // 5. Run build command, compile, or finish (type: c).
    if (target.buildCmd != null) return await _runBuildCmd();
    if (target.type == TargetType.bin) return await _compile(cFile);
    return true;
  }

  // ── step 0: fetch dependencies ────────────────────────────────────────────

  Future<void> _fetchDeps() async {
    _depInfos = await _depManager.ensureDeps();
  }

  // ── step 1: parse ─────────────────────────────────────────────────────────

  /// Path to the local std cache directory (extracted from embedded std).
  String get _stdCacheDir =>
      p.join(project.rootDir, '.micro-panda', 'std', 'src');

  /// Extract embedded std modules to the local cache if not already present.
  /// Target source overrides (files already in target's src dir) take priority and
  /// are never overwritten.
  void _ensureStd() {
    for (final entry in kStdlib.entries) {
      final rel = '${entry.key.replaceAll('.', p.separator)}.mpd';
      // Don't overwrite a project-level module.
      if (File(p.join(project.srcFor(target), rel)).existsSync()) continue;
      final dest = File(p.join(_stdCacheDir, rel));
      // Write if missing or outdated (compiler was updated with a new stdlib).
      if (!dest.existsSync() || dest.readAsStringSync() != entry.value) {
        dest.parent.createSync(recursive: true);
        dest.writeAsStringSync(entry.value);
      }
    }
  }

  List<Module>? _parseModules() {
    _ensureStd();

    // Build merged config: dep defaults (lower priority) + project config (overrides).
    // Dep defaults come from dep's mpd.yaml `default_config:` field.
    // Result is a single $config module with #define lines, emitted first in the C output.
    final extraModules = <Module>[];
    final merged = <String, String>{};

    // Layer 1: dep default configs.
    for (final dep in _depInfos.values) {
      if (dep.defaultConfig == null) continue;
      final path = p.join(_depManager.depDir(dep.name), dep.defaultConfig!);
      try {
        merged.addAll(parseConfigEntries(path));
        _log('  Config (dep default): ${dep.name}/${dep.defaultConfig}');
      } catch (e) {
        _error(e.toString());
        return null;
      }
    }

    // Layer 2: project config (overrides dep defaults).
    if (target.config != null) {
      final configPath = p.join(project.rootDir, target.config!);
      try {
        merged.addAll(parseConfigEntries(configPath));
        _log('  Config: ${target.config}');
      } catch (e) {
        _error(e.toString());
        return null;
      }
    }

    if (merged.isNotEmpty) {
      final data = buildConfigData(merged);
      _configVars = data.validatorTypes;
      extraModules.add(data.module);
      _log('  Config: ${merged.length} entries total');
    }

    final entryFile = _resolveEntry();
    if (!entryFile.existsSync()) {
      _error('Entry file not found: ${entryFile.path}');
      return null;
    }

    final visited = <String>{};
    final modules = <Module>[];
    final queue   = <File>[entryFile];

    while (queue.isNotEmpty) {
      final file    = queue.removeAt(0);
      final absPath = p.normalize(file.absolute.path);
      if (visited.contains(absPath)) continue;
      visited.add(absPath);

      _log('  Parsing ${p.relative(absPath, from: project.rootDir)}');

      try {
        final source = file.readAsStringSync();
        final sf         = SourceFile(absPath, 0, source.length);
        final modulePath = _modulePathFor(absPath);
        final flags      = Set<String>.from(target.flags);
        final (module, parseError) = Parser(sf, source, flags).parseModulePartial(modulePath);
        if (parseError != null) {
          stderr.writeln(parseError.toString());
          return null;
        }
        modules.add(module);

        // Enqueue imported modules.
        for (final imp in module.imports) {
          final importedFile = _resolveImport(imp.path, absPath);
          if (importedFile != null) queue.add(importedFile);
        }
      } catch (e) {
        stderr.writeln(e.toString());
        return null;
      }
    }

    // Normalize dep-internal import paths so the generator's reachability
    // traversal can follow them (e.g. bare `import pwm` → `led_driver.pwm`).
    final allModules = [...extraModules, ...modules];
    return _normalizeDepImports(allModules);
  }

  File _resolveEntry() {
    final rel     = '${target.entry.replaceAll('.', p.separator)}.mpd';
    final srcFile = File(p.join(project.srcFor(target), rel));
    if (srcFile.existsSync()) return srcFile;
    final testDir = project.testDirFor(target);
    if (testDir != null) {
      final testFile = File(p.join(testDir, rel));
      if (testFile.existsSync()) return testFile;
    }
    return srcFile; // return src path so error message is meaningful
  }

  /// Resolve an [importPath] string to a file.
  /// [fromAbsPath] is the absolute path of the file that contains the import —
  /// used to detect dep-internal (bare) imports and search that dep's src first.
  File? _resolveImport(String importPath, String fromAbsPath) {
    final rel = '${importPath.replaceAll('.', p.separator)}.mpd';

    // 1. If the calling file lives inside a dep, search that dep's src first
    //    so bare imports (e.g. `import utils` within led_driver) resolve locally.
    for (final dep in _depInfos.values) {
      final depSrc = p.normalize(_depManager.depSrcDir(dep.name));
      if (p.normalize(fromAbsPath).startsWith(depSrc)) {
        final internalFile = File(p.join(depSrc, rel));
        if (internalFile.existsSync()) return internalFile;
        break; // a file can only belong to one dep
      }
    }

    // 2. First path segment is a known dep name or lib_name → namespaced import from host.
    //    e.g. `import led_driver.pwm` or `import esp32.spi` with lib_name set
    final segments = importPath.split('.');
    if (segments.length > 1) {
      final prefix = segments.first;
      DepInfo? matched = _depInfos[prefix];
      if (matched == null) {
        for (final dep in _depInfos.values) {
          if (dep.libName == prefix) { matched = dep; break; }
        }
      }
      if (matched != null) {
        final innerRel = '${segments.skip(1).join(p.separator)}.mpd';
        final depFile  = File(p.join(_depManager.depSrcDir(matched.name), innerRel));
        if (depFile.existsSync()) return depFile;
      }
    }

    // 3. Project source (highest priority over std — allows overriding std modules).
    final projectFile = File(p.join(project.srcFor(target), rel));
    if (projectFile.existsSync()) return projectFile;

    // 4. Global deps (lib_name unset) — bare imports like `import i2c` resolve here.
    for (final dep in _depInfos.values) {
      if (dep.libName != null && dep.libName!.isNotEmpty) continue;
      final depFile = File(p.join(_depManager.depSrcDir(dep.name), rel));
      if (depFile.existsSync()) return depFile;
    }

    // 5. Extracted std cache.
    final stdFile = File(p.join(_stdCacheDir, rel));
    if (stdFile.existsSync()) return stdFile;

    return null;
  }

  String _modulePathFor(String absPath) {
    final normAbs = p.normalize(absPath);

    // Dep modules — prefix with lib_name when set, bare path when global (no lib_name).
    // e.g. lib_name "esp32": deps/esp32_hal/src/spi.mpd → "esp32.spi"
    //      lib_name unset:   deps/micro_gfx/src/gfx.mpd → "gfx"
    for (final dep in _depInfos.values) {
      final depSrc = p.normalize(_depManager.depSrcDir(dep.name));
      if (normAbs.startsWith(depSrc)) {
        final rel    = p.relative(absPath, from: _depManager.depSrcDir(dep.name));
        final inner  = p.withoutExtension(rel).replaceAll(p.separator, '.');
        final prefix = dep.libName;
        if (prefix == null || prefix.isEmpty) return inner;
        return '$prefix.$inner';
      }
    }

    // Std cache modules.
    final stdCache = p.normalize(_stdCacheDir);
    if (normAbs.startsWith(stdCache)) {
      final rel = p.relative(absPath, from: _stdCacheDir);
      return p.withoutExtension(rel).replaceAll(p.separator, '.');
    }

    // Test files live under the target's test directory.
    final testDir = project.testDirFor(target);
    if (testDir != null && normAbs.startsWith(p.normalize(testDir))) {
      final rel = p.relative(absPath, from: testDir);
      return p.withoutExtension(rel).replaceAll(p.separator, '.');
    }

    // Project source files.
    final rel = p.relative(absPath, from: project.srcFor(target));
    return p.withoutExtension(rel).replaceAll(p.separator, '.');
  }

  /// Rewrite import paths inside dep modules so bare internal imports become
  /// fully-qualified dep paths (e.g. `pwm` → `led_driver.pwm`).
  ///
  /// This is needed because `_filterReachable` in the generator follows import
  /// paths by string lookup, and the stored module paths are already dep-prefixed.
  List<Module> _normalizeDepImports(List<Module> modules) {
    if (_depInfos.isEmpty) return modules;

    return modules.map((module) {
      // Only rewrite imports in modules that belong to a dep.
      bool isDepModule = false;
      for (final dep in _depInfos.values) {
        if (p.normalize(module.sourceFile.name)
            .startsWith(p.normalize(_depManager.depSrcDir(dep.name)))) {
          isDepModule = true;
          break;
        }
      }
      if (!isDepModule) return module;

      var changed = false;
      final newImports = module.imports.map((imp) {
        // Resolve the import from within the dep context.
        final resolved = _resolveImport(imp.path, module.sourceFile.name);
        if (resolved == null) return imp;

        final absResolved = p.normalize(resolved.absolute.path);
        for (final dep in _depInfos.values) {
          final depSrc = p.normalize(_depManager.depSrcDir(dep.name));
          if (absResolved.startsWith(depSrc)) {
            final rel    = p.relative(absResolved, from: _depManager.depSrcDir(dep.name));
            final inner  = p.withoutExtension(rel).replaceAll(p.separator, '.');
            final prefix = dep.libName;
            final qualifiedPath = (prefix == null || prefix.isEmpty) ? inner : '$prefix.$inner';
            if (qualifiedPath == imp.path) return imp; // already qualified
            changed = true;
            return Import(qualifiedPath,
                symbol: imp.symbol, alias: imp.alias,
                isWildcard: imp.isWildcard, position: imp.position);
          }
        }
        return imp;
      }).toList();

      if (!changed) return module;
      return Module(module.path, module.sourceFile, module.rawBlocks,
          module.requiresConfig, newImports, module.variables, module.functions, module.classes, module.enums);
    }).toList();
  }

  // ── LSP analysis ──────────────────────────────────────────────────────────

  /// Parse and validate all modules for LSP use.
  /// Unlike [gen]/[build], this never returns null — partial results and all
  /// errors are returned so the LSP can push diagnostics and still serve completions.
  Future<LspAnalysis> analyzeForLsp() async {
    // LSP: use only cached deps — never fetch over the network during editing.
    _depInfos = await _depManager.ensureDeps(lspMode: true);
    _ensureStd();

    final extraModules = <Module>[];
    final merged = <String, String>{};
    final parseErrors = <CompileException>[];
    final configErrors = <String>[];

    // Merge config (same as _parseModules).
    for (final dep in _depInfos.values) {
      if (dep.defaultConfig == null) continue;
      final path = p.join(_depManager.depDir(dep.name), dep.defaultConfig!);
      try {
        merged.addAll(parseConfigEntries(path));
      } catch (_) {}
    }
    if (target.config != null) {
      final configPath = p.join(project.rootDir, target.config!);
      try {
        merged.addAll(parseConfigEntries(configPath));
      } catch (_) {}
    }
    if (merged.isNotEmpty) {
      final data = buildConfigData(merged);
      _configVars = data.validatorTypes;
      extraModules.add(data.module);
    }

    // Parse all modules tolerantly.
    // In LSP mode, seed the queue with every .mpd file under the project src dir
    // so completions work in library files that aren't imported from the entry.
    final entryFile = _resolveEntry();
    final visited = <String>{};
    final modules = <Module>[];
    final queue = <File>[if (entryFile.existsSync()) entryFile];
    final srcDir = Directory(project.srcFor(target));
    if (srcDir.existsSync()) {
      for (final entity in srcDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.mpd')) {
          queue.add(entity);
        }
      }
    }

    while (queue.isNotEmpty) {
      final file = queue.removeAt(0);
      final absPath = p.normalize(file.absolute.path);
      if (visited.contains(absPath)) continue;
      visited.add(absPath);

      try {
        final source = file.readAsStringSync();
        final sf = SourceFile(absPath, 0, source.length);
        final modulePath = _modulePathFor(absPath);
        final flags = Set<String>.from(target.flags);
        final parser = Parser(sf, source, flags);
        final (mod, err) = parser.parseModulePartial(modulePath);
        modules.add(mod);
        if (err != null) parseErrors.add(err);

        for (final imp in mod.imports) {
          final importedFile = _resolveImport(imp.path, absPath);
          if (importedFile != null) queue.add(importedFile);
        }
      } catch (_) {}
    }

    final allModules = _normalizeDepImports([...extraModules, ...modules]);

    // Check @require config keys.
    for (final mod in allModules) {
      for (final key in mod.requiresConfig) {
        if (!_configVars.containsKey(key)) {
          configErrors.add('${mod.path}: config key "$key" is required but not defined');
        }
      }
    }

    // Semantic validation.
    final validationErrors = Validator().validate(allModules, configVars: _configVars);

    return LspAnalysis(allModules, parseErrors, configErrors, validationErrors);
  }

  // ── step 2: validate ──────────────────────────────────────────────────────

  bool _validate(List<Module> modules) {
    _log('  Validating...');
    var ok = true;

    // Check @require(KEY) annotations against the merged config.
    for (final mod in modules) {
      for (final key in mod.requiresConfig) {
        if (!_configVars.containsKey(key)) {
          stderr.writeln('${mod.path}: config key "$key" is required but not defined');
          ok = false;
        }
      }
    }

    final errors = Validator().validate(modules, configVars: _configVars);
    for (final e in errors) {
      stderr.writeln(e.toString());
    }
    return ok && errors.isEmpty;
  }

  // ── step 3: generate C ────────────────────────────────────────────────────

  String _generateC(List<Module> modules) {
    _log('  Generating C...');
    return CGenerator().generate(modules, entryModPath: target.entry, entryFn: target.gen.entryFn);
  }

  // ── step 4: write C file ──────────────────────────────────────────────────

  File? _writeCFile(String cCode) {
    try {
      final cFile = File(project.outFileFor(target));
      cFile.parent.createSync(recursive: true);
      cFile.writeAsStringSync(cCode);
      _log('  Written ${p.relative(cFile.path, from: project.rootDir)}');
      return cFile;
    } catch (e) {
      _error('Failed to write C file: $e');
      return null;
    }
  }

  // ── step 5a: simple mode — invoke C compiler ──────────────────────────────

  Future<bool> _compile(File cFile) async {
    final cc     = target.cc?.exe ?? 'gcc';
    final output = _resolveOutput();

    // Ensure output directory exists.
    final outDir = Directory(p.dirname(output));
    if (!outDir.existsSync()) outDir.createSync(recursive: true);

    final args = [
      ...?target.cc?.flags,
      cFile.path,
      '-o', output,
    ];

    _log('  Compiling: $cc ${args.join(' ')}');
    final result = await Process.run(cc, args, workingDirectory: project.rootDir);

    if (result.exitCode != 0) {
      if (result.stdout.toString().isNotEmpty) stdout.write(result.stdout);
      if (result.stderr.toString().isNotEmpty) stderr.write(result.stderr);
      _error('Compilation failed (exit ${result.exitCode})');
      return false;
    }

    _log('  Output: $output');
    return true;
  }

  // ── step 5b: custom mode — run external build system ─────────────────────

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
    final buf   = StringBuffer();
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

/// Result of [Builder.analyzeForLsp]: partial modules + all errors.
class LspAnalysis {
  final List<Module> modules;
  final List<CompileException> parseErrors;
  final List<String> configErrors;
  final List<ValidationError> validationErrors;

  LspAnalysis(this.modules, this.parseErrors, this.configErrors, this.validationErrors);
}
