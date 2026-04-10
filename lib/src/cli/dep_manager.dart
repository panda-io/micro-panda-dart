import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'project.dart';

/// Resolved information about a fetched dependency (written to the lock file).
class DepInfo {
  final String name;           // from dep's mpd.yaml `name:`
  final String? libName;       // from dep's mpd.yaml `lib_name:` — null = global (no prefix)
  final String? defaultConfig; // from dep's mpd.yaml `default_config:` — path relative to dep root
  final String url;            // original git URL
  final String version;        // "0.1.0" or "latest"
  final String commit;         // resolved git SHA

  DepInfo({required this.name, this.libName, this.defaultConfig, required this.url, required this.version, required this.commit});
}

/// Manages git-based dependency fetching and caching under `.micro-panda/deps/`.
class DepManager {
  final Project project;

  DepManager(this.project);

  String get _depsDir  => p.join(project.rootDir, '.micro-panda', 'deps');
  String get _lockPath => p.join(project.rootDir, '.micro-panda', 'deps.lock');

  /// Absolute path to the cloned directory for [depName].
  String depDir(String depName) => p.join(_depsDir, depName);

  /// Absolute path to the source directory inside the dep.
  String depSrcDir(String depName) => p.join(_depsDir, depName, 'src');

  /// Ensure all deps declared in [project.deps] are present on disk.
  /// Skips a dep if it is already cached at the matching version (per lock file).
  /// If [forceUpdate] is true, re-fetches every dep regardless.
  /// Returns a map of dep name → [DepInfo].
  Future<Map<String, DepInfo>> ensureDeps({bool forceUpdate = false, bool lspMode = false}) async {
    if (project.deps.isEmpty) return {};

    final lock   = _loadLock();
    final result = <String, DepInfo>{};

    for (final dep in project.deps) {
      final cached = lock[dep.url];
      final dirExists = cached != null && Directory(depDir(cached.name)).existsSync();

      // Use the cached version unless: force-update requested (mpd update),
      // or not cached yet.
      final needsFetch = forceUpdate || !dirExists;

      if (!needsFetch) {
        result[cached!.name] = cached;
        continue;
      }
      // LSP mode: skip network fetch — dep not cached yet, just ignore it.
      if (lspMode) continue;
      final info = await _fetchDep(dep);
      lock[dep.url] = info;
      result[info.name] = info;
    }

    _saveLock(lock);
    return result;
  }

  Future<DepInfo> _fetchDep(Dep dep) async {
    Directory(_depsDir).createSync(recursive: true);

    // Clone into a temp dir first so we can read the dep name before choosing the final path.
    final tempPath = p.join(_depsDir, '_fetch_${DateTime.now().millisecondsSinceEpoch}');
    final cloneArgs = dep.version == 'latest'
        ? ['clone', '--depth', '1', dep.url, tempPath]
        : ['clone', '--branch', dep.version, '--depth', '1', dep.url, tempPath];

    stdout.writeln('Fetching ${dep.url}@${dep.version}...');
    final cloneResult = await Process.run('git', cloneArgs);
    if (cloneResult.exitCode != 0) {
      if (cloneResult.stderr.toString().isNotEmpty) stderr.write(cloneResult.stderr);
      throw Exception('Failed to clone ${dep.url} (exit ${cloneResult.exitCode})');
    }

    // Read canonical name from dep's own mpd.yaml.
    final yamlFile = File(p.join(tempPath, 'mpd.yaml'));
    if (!yamlFile.existsSync()) {
      Directory(tempPath).deleteSync(recursive: true);
      throw Exception('Dep ${dep.url} has no mpd.yaml');
    }
    final doc = loadYaml(yamlFile.readAsStringSync()) as YamlMap;
    final name = doc['name'] as String?;
    if (name == null || !RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name)) {
      Directory(tempPath).deleteSync(recursive: true);
      throw Exception(
          'Dep ${dep.url}: "name" in mpd.yaml is missing or not a valid identifier (got: $name)');
    }
    final libName       = doc['lib_name']       as String?;
    final defaultConfig = doc['default_config'] as String?;

    // Resolve commit SHA.
    final revResult = await Process.run('git', ['-C', tempPath, 'rev-parse', 'HEAD']);
    final commit    = revResult.stdout.toString().trim();

    // Move to final location.
    final finalPath = depDir(name);
    if (Directory(finalPath).existsSync()) Directory(finalPath).deleteSync(recursive: true);
    Directory(tempPath).renameSync(finalPath);

    stdout.writeln('  → $name @ ${commit.length >= 7 ? commit.substring(0, 7) : commit}');
    return DepInfo(name: name, libName: libName, defaultConfig: defaultConfig, url: dep.url, version: dep.version, commit: commit);
  }

  // ── lock file ──────────────────────────────────────────────────────────────

  /// Load the lock file. Returns a map of URL → [DepInfo].
  Map<String, DepInfo> _loadLock() {
    final file = File(_lockPath);
    if (!file.existsSync()) return {};
    try {
      final doc = loadYaml(file.readAsStringSync());
      if (doc is! YamlList) return {};
      final result = <String, DepInfo>{};
      for (final entry in doc) {
        if (entry is! YamlMap) continue;
        final info = DepInfo(
          name:          entry['name']           as String? ?? '',
          libName:       entry['lib_name']        as String?,
          defaultConfig: entry['default_config']  as String?,
          url:           entry['url']             as String? ?? '',
          version:       entry['version']         as String? ?? '',
          commit:        entry['commit']           as String? ?? '',
        );
        if (info.url.isNotEmpty && info.name.isNotEmpty) result[info.url] = info;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  void _saveLock(Map<String, DepInfo> lock) {
    final file = File(_lockPath);
    file.parent.createSync(recursive: true);
    final buf = StringBuffer();
    for (final info in lock.values) {
      buf.writeln('- name: ${info.name}');
      if (info.libName       != null) buf.writeln('  lib_name: ${info.libName}');
      if (info.defaultConfig != null) buf.writeln('  default_config: ${info.defaultConfig}');
      buf.writeln('  url: ${info.url}');
      buf.writeln('  version: "${info.version}"');
      buf.writeln('  commit: ${info.commit}');
    }
    file.writeAsStringSync(buf.toString());
  }
}
