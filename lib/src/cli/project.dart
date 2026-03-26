import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

enum TargetType { c, bin }

/// C compiler settings — lives under the `cc:` sub-node of a target.
class CcConfig {
  /// Compiler executable name (e.g. "gcc", "arm-none-eabi-gcc").
  final String bin;

  /// Directory containing [bin]. If null, resolved from PATH.
  final String? path;

  /// Extra compiler flags (e.g. ["-O2", "-Wall"]).
  final List<String> flags;

  CcConfig({this.bin = 'gcc', this.path, this.flags = const []});

  factory CcConfig.fromYaml(YamlMap yaml) => CcConfig(
        bin: yaml['bin'] as String? ?? 'gcc',
        path: yaml['path'] as String?,
        flags: _stringList(yaml['flags']),
      );

  /// Resolved compiler binary path.
  String get exe => path != null ? p.join(path!, bin) : bin;
}

/// Code-generation settings — lives under the `gen:` sub-node of a target.
class GenConfig {
  /// C entry function name (e.g. "main", "app_main").
  final String entryFn;

  GenConfig({this.entryFn = 'main'});

  factory GenConfig.fromYaml(YamlMap yaml) => GenConfig(
        entryFn: yaml['entry'] as String? ?? 'main',
      );
}

/// A build target defined in mpd.yaml.
class Target {
  final String name;

  /// Entry module name (e.g. "main" → resolves to `src/main.mpd`).
  final String entry;

  /// What this target produces: [TargetType.c] = C file only, [TargetType.bin] = compiled binary.
  final TargetType type;

  /// Micro-panda conditional compile flags (e.g. [DEBUG, MCU32]).
  final List<String> flags;

  /// Shell command to run after C generation (e.g. "idf.py build").
  final String? buildCmd;

  /// Code-generation settings (entry function name).
  final GenConfig gen;

  /// C compiler settings. Required when [type] is [TargetType.bin].
  final CcConfig? cc;

  /// Key-value config file path (relative to project root).
  /// Entries are globally visible in all modules without import.
  final String? config;

  /// Per-target source folder. Defaults to `src/` when omitted.
  final String? src;

  /// Test files folder. When set, `mpd test` discovers `*_test.mpd` here.
  final String? test;

  /// Output file path (e.g. "main/esp32.c"). Falls back to `out/<name>.c`.
  final String? out;

  /// Final binary artifact path (exe). Used by simple-mode compilation.
  final String? output;

  Target({
    required this.name,
    required this.entry,
    required this.type,
    this.flags = const [],
    this.buildCmd,
    GenConfig? gen,
    this.cc,
    this.config,
    this.src,
    this.test,
    this.out,
    this.output,
  }) : gen = gen ?? GenConfig();

  factory Target.fromYaml(String name, YamlMap yaml) {
    final rawType = yaml['type'] as String?;
    if (rawType == null) throw Exception('target "$name": missing required field "type"');
    final type = switch (rawType) {
      'c'   => TargetType.c,
      'bin' => TargetType.bin,
      _     => throw Exception('target "$name": unknown type "$rawType" (expected "c" or "bin")'),
    };

    final rawGen = yaml['gen'];
    final rawCc  = yaml['cc'];

    return Target(
      name:     name,
      entry:    yaml['entry'] as String? ?? 'main',
      type:     type,
      flags:    _stringList(yaml['flags']),
      buildCmd: yaml['build_cmd'] as String?,
      gen:      rawGen is YamlMap ? GenConfig.fromYaml(rawGen) : GenConfig(),
      cc:       rawCc  is YamlMap ? CcConfig.fromYaml(rawCc)   : null,
      config:   yaml['config'] as String?,
      src:      yaml['src']    as String?,
      test:     yaml['test']   as String?,
      out:      yaml['out']    as String?,
      output:   yaml['output'] as String?,
    );
  }
}

/// Parsed representation of mpd.yaml.
class Project {
  final String name;
  final String version;
  final Map<String, Target> targets;

  /// Project root directory (where mpd.yaml lives).
  final String rootDir;

  /// Default output directory for generated C files. Convention: `<root>/out/`.
  String get out => p.join(rootDir, 'out');

  Project({
    required this.name,
    required this.version,
    required this.targets,
    required this.rootDir,
  });

  /// Load and parse [mpd.yaml] from [projectDir] (or current directory).
  static Project load([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final yamlFile = File(p.join(dir, 'mpd.yaml'));
    if (!yamlFile.existsSync()) throw Exception('mpd.yaml not found in $dir');

    final doc = loadYaml(yamlFile.readAsStringSync()) as YamlMap;

    final name    = doc['name']    as String? ?? p.basename(dir);
    final version = doc['version'] as String? ?? '0.1.0';

    final targets = <String, Target>{};
    final rawTargets = doc['targets'];
    if (rawTargets is YamlMap) {
      for (final entry in rawTargets.entries) {
        final targetName = entry.key as String;
        final targetYaml = entry.value as YamlMap;
        targets[targetName] = Target.fromYaml(targetName, targetYaml);
      }
    }

    return Project(name: name, version: version, targets: targets, rootDir: dir);
  }

  /// Resolve the source directory for a given target. Defaults to `<root>/src/`.
  String srcFor(Target target) => p.join(rootDir, target.src ?? 'src');

  /// Resolve the test directory for a given target. Returns null if [Target.test] is unset.
  String? testDirFor(Target target) =>
      target.test != null ? p.join(rootDir, target.test!) : null;

  /// Resolve the output file path for a given target.
  /// Uses [Target.out] when set; otherwise `<out>/<name>.c`.
  String outFileFor(Target target) =>
      target.out != null ? p.join(rootDir, target.out!) : p.join(out, '${target.name}.c');
}

List<String> _stringList(dynamic value) {
  if (value == null) return const [];
  if (value is YamlList) return value.map((e) => e.toString()).toList();
  return const [];
}
