import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// A build target defined in mpd.yaml.
class Target {
  final String name;

  /// Entry module name (e.g. "main" → resolves to `src/main.mpd`).
  final String entry;

  /// Micro-panda conditional compile flags (e.g. [debug, esp8266]).
  final List<String> flags;

  // ── simple mode (mpd drives compilation) ─────────────────────────────────

  /// C compiler executable name (e.g. "gcc", "arm-none-eabi-gcc").
  final String? cc;

  /// Directory containing `cc` binary. If null, resolved from PATH.
  final String? ccPath;

  /// Extra C compiler flags (e.g. ["-O2", "-Wall"]).
  final List<String> cflags;

  /// Platform identifier — must match a key under `platforms:` in mpd.yaml.
  final String? platform;

  // ── custom mode (external build system) ──────────────────────────────────

  /// Shell command to run after C generation (e.g. "make -C sdk/ -j4").
  final String? buildCmd;

  // ── mcu / platform ────────────────────────────────────────────────────────

  /// Entry function name. Defaults to `main`. Use `app_main` for ESP-IDF targets.
  /// Resolved from: explicit `entry_fn` key > platform defaults > `'main'`.
  final String entryFn;

  // ── shared ────────────────────────────────────────────────────────────────

  /// Where generated C files are written. Overrides project-level [Project.out].
  final String? out;

  /// Final output artifact path (exe or firmware binary).
  final String? output;

  bool get isCustomMode => buildCmd != null;

  Target({
    required this.name,
    required this.entry,
    this.flags = const [],
    this.cc,
    this.ccPath,
    this.cflags = const [],
    this.platform,
    this.buildCmd,
    this.entryFn = 'main',
    this.out,
    this.output,
  });

  factory Target.fromYaml(
    String name,
    YamlMap yaml, {
    Map<String, Map<String, String>> platforms = const {},
  }) {
    final platform = yaml['platform'] as String?;

    // Resolve entry_fn: explicit target key > platform defaults > 'main'.
    String resolvedEntryFn = 'main';
    if (platform != null) {
      final platformDef = platforms[platform];
      if (platformDef != null && platformDef['entry_fn'] != null) {
        resolvedEntryFn = platformDef['entry_fn']!;
      }
    }
    if (yaml['entry_fn'] is String) resolvedEntryFn = yaml['entry_fn'] as String;

    return Target(
      name: name,
      entry: yaml['entry'] as String? ?? 'main',
      flags: _stringList(yaml['flags']),
      cc: yaml['cc'] as String?,
      ccPath: yaml['cc_path'] as String?,
      cflags: _stringList(yaml['cflags']),
      platform: platform,
      buildCmd: yaml['build_cmd'] as String?,
      entryFn: resolvedEntryFn,
      out: yaml['out'] as String?,
      output: yaml['output'] as String?,
    );
  }

  /// Resolved compiler binary path.
  String get ccBin {
    final name = cc ?? 'gcc';
    if (ccPath != null) return p.join(ccPath!, name);
    return name;
  }
}

/// Parsed representation of mpd.yaml.
class Project {
  final String name;
  final String version;

  /// Source root directory (absolute).
  final String src;

  /// Default output directory for generated C files (absolute).
  final String out;

  /// Test files directory (absolute). Defaults to src/.
  final String test;

  final Map<String, Target> targets;

  /// Project root directory (where mpd.yaml lives).
  final String rootDir;

  Project({
    required this.name,
    required this.version,
    required this.src,
    required this.out,
    required this.test,
    required this.targets,
    required this.rootDir,
  });

  /// Load and parse [mpd.yaml] from [projectDir] (or current directory).
  static Project load([String? projectDir]) {
    final dir = projectDir ?? Directory.current.path;
    final yamlFile = File(p.join(dir, 'mpd.yaml'));
    if (!yamlFile.existsSync()) {
      throw Exception('mpd.yaml not found in $dir');
    }

    final doc = loadYaml(yamlFile.readAsStringSync()) as YamlMap;

    final name = doc['name'] as String? ?? p.basename(dir);
    final version = doc['version'] as String? ?? '0.1.0';
    final srcRel = doc['src'] as String? ?? 'src';
    final outRel = doc['out'] as String? ?? 'out';
    final testRel = doc['test'] as String? ?? srcRel;

    // Parse platform definitions.
    final platforms = <String, Map<String, String>>{};
    final rawPlatforms = doc['platforms'];
    if (rawPlatforms is YamlMap) {
      for (final entry in rawPlatforms.entries) {
        final pName = entry.key as String;
        final pYaml = entry.value;
        if (pYaml is YamlMap) {
          platforms[pName] = {
            for (final kv in pYaml.entries)
              kv.key.toString(): kv.value.toString()
          };
        }
      }
    }

    final targets = <String, Target>{};
    final rawTargets = doc['targets'];
    if (rawTargets is YamlMap) {
      for (final entry in rawTargets.entries) {
        final targetName = entry.key as String;
        final targetYaml = entry.value as YamlMap;
        targets[targetName] =
            Target.fromYaml(targetName, targetYaml, platforms: platforms);
      }
    }

    return Project(
      name: name,
      version: version,
      src: p.join(dir, srcRel),
      out: p.join(dir, outRel),
      test: p.join(dir, testRel),
      targets: targets,
      rootDir: dir,
    );
  }

  /// Resolve the output directory for a given target (target-level overrides project-level).
  String outDirFor(Target target) =>
      target.out != null ? p.join(rootDir, target.out!) : out;
}

List<String> _stringList(dynamic value) {
  if (value == null) return const [];
  if (value is YamlList) return value.map((e) => e.toString()).toList();
  return const [];
}
