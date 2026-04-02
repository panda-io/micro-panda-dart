/// A named target template used by `mpd init` and `mpd target add`.
class TargetTemplate {
  final String description;

  /// YAML body for the target fields — 4-space indented, `{name}` substituted at render time.
  final String _body;

  const TargetTemplate(this.description, this._body);

  /// Returns the full YAML block ready to append under `targets:`.
  String render(String name) {
    final body = _body.replaceAll('{name}', name);
    return '  $name:\n$body\n';
  }
}

const kTemplates = <String, TargetTemplate>{
  'hosted-debug': TargetTemplate(
    'Desktop binary, debug build (gcc -g -O0)',
    '    entry: main\n'
    '    src: src/\n'
    '    test: test/\n'
    '    type: bin\n'
    '    flags: [DEBUG, HOSTED]\n'
    '    output: bin/{name}\n'
    '    cc:\n'
    '      bin: gcc\n'
    '      flags: [-g, -O0, -Wall]',
  ),
  'hosted-release': TargetTemplate(
    'Desktop binary, optimised release build (gcc -O2)',
    '    entry: main\n'
    '    src: src/\n'
    '    test: test/\n'
    '    type: bin\n'
    '    flags: [HOSTED]\n'
    '    output: bin/{name}\n'
    '    cc:\n'
    '      bin: gcc\n'
    '      flags: [-O2, -Wall]',
  ),
  'esp32-debug': TargetTemplate(
    'ESP32 via ESP-IDF, debug build',
    '    entry: main\n'
    '    src: src/\n'
    '    out: main/{name}.c\n'
    '    type: c\n'
    '    flags: [MCU32, DEBUG]\n'
    '    build_cmd: idf.py build\n'
    '    gen:\n'
    '      entry: app_main',
  ),
  'esp32-release': TargetTemplate(
    'ESP32 via ESP-IDF, release build',
    '    entry: main\n'
    '    src: src/\n'
    '    out: main/{name}.c\n'
    '    type: c\n'
    '    flags: [MCU32]\n'
    '    build_cmd: idf.py build\n'
    '    gen:\n'
    '      entry: app_main',
  ),
};

const kInitTemplate = 'hosted-debug';
const kInitEntryModule = 'main';
const kInitMainMpd = 'import console::*\n\nfun main()\n    print("Hello, world!")\n';
