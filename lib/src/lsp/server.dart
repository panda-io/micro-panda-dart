import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ast/declaration/function_decl.dart';
import '../ast/declaration/variable_decl.dart';
import '../ast/module.dart';
import '../ast/type/type_builtin.dart';
import '../ast/type/type_function.dart';
import '../ast/type/type_name.dart';
import '../ast/type/type_ref.dart';
import '../ast/type/type_array.dart';
import '../cli/builder.dart';
import '../cli/project.dart';

// ── LSP completion item kinds ─────────────────────────────────────────────────

const _kindFunction = 3;
const _kindVariable = 6;
const _kindClass    = 7;
const _kindEnum     = 13;
const _kindConstant = 21;

// ── LSP diagnostic severities ─────────────────────────────────────────────────

const _severityError = 1;

// ── server ────────────────────────────────────────────────────────────────────

class LspServer {
  /// The workspace root sent during `initialize`.
  String? _workspaceRoot;

  /// Loaded project (mpd.yaml). Null until [_workspaceRoot] is set.
  Project? _project;

  /// All modules from the last successful analysis pass.
  List<Module> _modules = [];

  /// Open file contents: file URI → text sent by VS Code.
  final Map<String, String> _openFiles = {};

  /// True after the client sends `shutdown`.
  bool _shuttingDown = false;

  // ── entry point ─────────────────────────────────────────────────────────────

  Future<void> run() async {
    final buffer = <int>[];
    await for (final chunk in stdin) {
      buffer.addAll(chunk);
      while (true) {
        final msg = _tryReadMessage(buffer);
        if (msg == null) break;
        await _dispatch(msg);
      }
    }
  }

  // ── JSON-RPC transport ───────────────────────────────────────────────────────

  /// Try to extract one complete LSP message from [buffer].
  /// Removes consumed bytes from [buffer] and returns the parsed JSON.
  /// Returns null if the buffer does not yet contain a complete message.
  Map<String, dynamic>? _tryReadMessage(List<int> buffer) {
    // Find header/body separator: \r\n\r\n
    for (int i = 0; i < buffer.length - 3; i++) {
      if (buffer[i] == 13 && buffer[i + 1] == 10 &&
          buffer[i + 2] == 13 && buffer[i + 3] == 10) {
        final header = utf8.decode(buffer.sublist(0, i));
        int? contentLength;
        for (final line in header.split('\r\n')) {
          if (line.toLowerCase().startsWith('content-length:')) {
            contentLength = int.tryParse(line.split(':')[1].trim());
          }
        }
        if (contentLength == null) return null;
        final bodyStart = i + 4;
        if (buffer.length < bodyStart + contentLength) return null;

        final body = utf8.decode(buffer.sublist(bodyStart, bodyStart + contentLength));
        buffer.removeRange(0, bodyStart + contentLength);
        return jsonDecode(body) as Map<String, dynamic>;
      }
    }
    return null;
  }

  void _send(Map<String, dynamic> msg) {
    final body = jsonEncode(msg);
    final bytes = utf8.encode(body);
    stdout.write('Content-Length: ${bytes.length}\r\n\r\n');
    stdout.add(bytes);
    stdout.flush();
  }

  void _respond(dynamic id, dynamic result) {
    _send({'jsonrpc': '2.0', 'id': id, 'result': result});
  }

  void _respondError(dynamic id, int code, String message) {
    _send({'jsonrpc': '2.0', 'id': id, 'error': {'code': code, 'message': message}});
  }

  void _notify(String method, dynamic params) {
    _send({'jsonrpc': '2.0', 'method': method, 'params': params});
  }

  // ── dispatcher ───────────────────────────────────────────────────────────────

  Future<void> _dispatch(Map<String, dynamic> msg) async {
    final method = msg['method'] as String?;
    final id     = msg['id'];
    final params = msg['params'] as Map<String, dynamic>? ?? {};

    if (method == null) return; // response, ignore

    switch (method) {
      case 'initialize':
        _respond(id, _handleInitialize(params));
      case 'initialized':
        break; // no-op notification
      case 'shutdown':
        _shuttingDown = true;
        _respond(id, null);
      case 'exit':
        exit(_shuttingDown ? 0 : 1);
      case 'textDocument/didOpen':
        final doc = params['textDocument'] as Map<String, dynamic>;
        _openFiles[doc['uri'] as String] = doc['text'] as String;
        await _analyzeAndPublish(doc['uri'] as String);
      case 'textDocument/didChange':
        final doc     = params['textDocument'] as Map<String, dynamic>;
        final changes = params['contentChanges'] as List<dynamic>;
        if (changes.isNotEmpty) {
          _openFiles[doc['uri'] as String] =
              (changes.last as Map<String, dynamic>)['text'] as String;
        }
      case 'textDocument/didSave':
        final doc = params['textDocument'] as Map<String, dynamic>;
        await _analyzeAndPublish(doc['uri'] as String);
      case 'textDocument/didClose':
        final doc = params['textDocument'] as Map<String, dynamic>;
        _openFiles.remove(doc['uri'] as String);
        // Clear diagnostics for the closed file.
        _notify('textDocument/publishDiagnostics',
            {'uri': doc['uri'], 'diagnostics': <Map<String, dynamic>>[]});
      case 'textDocument/completion':
        _respond(id, _handleCompletion(params));
      default:
        if (id != null) _respondError(id, -32601, 'Method not found: $method');
    }
  }

  // ── initialize ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _handleInitialize(Map<String, dynamic> params) {
    final rootUri = params['rootUri'] as String?;
    if (rootUri != null) {
      _workspaceRoot = _uriToPath(rootUri);
      _tryLoadProject();
    }
    return {
      'capabilities': {
        'textDocumentSync': {
          'openClose': true,
          'change': 1, // full sync
          'save': true,
        },
        'completionProvider': {
          'triggerCharacters': ['_'],
        },
      },
      'serverInfo': {'name': 'mpd-lsp', 'version': '0.1.0'},
    };
  }

  void _tryLoadProject() {
    if (_workspaceRoot == null) return;
    try {
      _project = Project.load(_workspaceRoot);
    } catch (_) {
      _project = null;
    }
  }

  // ── analysis + diagnostics ───────────────────────────────────────────────────

  Future<void> _analyzeAndPublish(String uri) async {
    final project = _project;
    if (project == null || project.targets.isEmpty) return;

    // Use first target for analysis.
    final target = project.targets.values.first;
    final analysis = await Builder(project, target).analyzeForLsp();
    _modules = analysis.modules;

    // Group all errors by file path.
    final Map<String, List<Map<String, dynamic>>> byFile = <String, List<Map<String, dynamic>>>{};

    void addDiag(String filePath, int line, int col, int severity, String message) {
      // LSP positions are 0-indexed.
      final range = _range(line - 1, col - 1, line - 1, col - 1 + 1);
      byFile.putIfAbsent(filePath, () => []).add({
        'range': range,
        'severity': severity,
        'message': message,
        'source': 'mpd',
      });
    }

    for (final e in analysis.parseErrors) {
      addDiag(e.filePath, e.line, e.col, _severityError, e.message);
    }
    for (final msg in analysis.configErrors) {
      // Config errors have no position — attach to the entry file.
      final entryPath = _uriToPath(uri);
      addDiag(entryPath, 1, 1, _severityError, msg);
    }
    for (final e in analysis.validationErrors) {
      if (e.file == null) continue;
      final (line, col) = e.file!.getLocation(e.position);
      addDiag(e.file!.name, line, col, _severityError, e.message);
    }

    // Publish diagnostics for every file that has errors.
    // Also clear diagnostics for files that now have none.
    final allFiles = {
      ...byFile.keys,
      ..._modules.map((m) => m.sourceFile.name),
    };
    for (final filePath in allFiles) {
      _notify('textDocument/publishDiagnostics', {
        'uri': _pathToUri(filePath),
        'diagnostics': byFile[filePath] ?? [],
      });
    }
  }

  // ── completion ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _handleCompletion(Map<String, dynamic> params) {
    final uri      = (params['textDocument'] as Map)['uri'] as String;
    final position = params['position'] as Map<String, dynamic>;
    final line     = position['line'] as int;     // 0-indexed
    final char     = position['character'] as int; // 0-indexed

    final prefix = _prefixAt(uri, line, char);
    final items  = _completionItems(prefix);
    return {'isIncomplete': false, 'items': items};
  }

  /// Extract the identifier prefix the user is currently typing.
  String _prefixAt(String uri, int line, int character) {
    final content = _openFiles[uri];
    if (content == null) return '';
    final lines = content.split('\n');
    if (line >= lines.length) return '';
    final lineText = lines[line];
    final col      = character.clamp(0, lineText.length);
    // Walk backwards while character is a valid identifier character.
    int start = col;
    while (start > 0 && _isIdentChar(lineText[start - 1])) {
      start--;
    }
    return lineText.substring(start, col);
  }

  bool _isIdentChar(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) ||  // A-Z
           (c >= 97 && c <= 122) || // a-z
           (c >= 48 && c <= 57) ||  // 0-9
           c == 95;                  // _
  }

  List<Map<String, dynamic>> _completionItems(String prefix) {
    final items = <Map<String, dynamic>>[];
    final seen  = <String>{};

    for (final mod in _modules) {
      // Skip private/internal modules and the config pseudo-module.
      if (mod.path.startsWith(r'$')) continue;

      for (final fn in mod.functions) {
        if (!fn.isPublic) continue;
        if (!fn.name.startsWith(prefix)) continue;
        if (!seen.add(fn.name)) continue;
        items.add(_fnItem(fn));
      }

      for (final v in mod.variables) {
        if (!v.isPublic) continue;
        if (!v.name.startsWith(prefix)) continue;
        if (!seen.add(v.name)) continue;
        items.add(_varItem(v));
      }

      for (final cls in mod.classes) {
        if (!cls.isPublic) continue;
        if (!cls.name.startsWith(prefix)) continue;
        if (!seen.add(cls.name)) continue;
        items.add({'label': cls.name, 'kind': _kindClass});
      }

      for (final enm in mod.enums) {
        if (!enm.isPublic) continue;
        if (!enm.name.startsWith(prefix)) continue;
        if (!seen.add(enm.name)) continue;
        items.add({'label': enm.name, 'kind': _kindEnum});
      }
    }

    return items;
  }

  Map<String, dynamic> _fnItem(FunctionDecl fn) {
    final params = fn.parameters.map((p) => '${p.name}: ${_typeStr(p.type)}').join(', ');
    final ret    = fn.returnType != null ? ' ${_typeStr(fn.returnType!)}' : '';
    return {
      'label':  fn.name,
      'kind':   _kindFunction,
      'detail': 'fun ${fn.name}($params)$ret',
    };
  }

  Map<String, dynamic> _varItem(VariableDecl v) {
    final kind   = v.isConst ? _kindConstant : _kindVariable;
    final detail = v.type != null ? _typeStr(v.type!) : 'var';
    return {'label': v.name, 'kind': kind, 'detail': detail};
  }

  // ── type pretty-print ────────────────────────────────────────────────────────

  String _typeStr(dynamic type) {
    if (type == null) return 'void';
    if (type is TypeBuiltin) return type.token.literal ?? type.token.name;
    if (type is TypeName)    return type.name ?? '?';
    if (type is TypeRef)     return '&${_typeStr(type.elementType)}';
    if (type is TypeArray)   return '${_typeStr(type.elementType)}[]';
    if (type is TypeFunction) {
      final ps = type.parameters.map(_typeStr).join(', ');
      final r  = type.returnTypes.isNotEmpty ? ' ${_typeStr(type.returnTypes.first)}' : '';
      return 'fun($ps)$r';
    }
    return type.toString();
  }

  // ── URI helpers ──────────────────────────────────────────────────────────────

  String _uriToPath(String uri) {
    if (uri.startsWith('file://')) {
      return Uri.parse(uri).toFilePath();
    }
    return uri;
  }

  String _pathToUri(String path) {
    return Uri.file(path).toString();
  }

  // ── LSP range helper ─────────────────────────────────────────────────────────

  Map<String, dynamic> _range(int startLine, int startChar, int endLine, int endChar) => {
    'start': {'line': startLine, 'character': startChar},
    'end':   {'line': endLine,   'character': endChar},
  };
}
