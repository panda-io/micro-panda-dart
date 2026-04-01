import 'dart:async' show Completer;
import 'dart:convert';
import 'dart:io';

import '../ast/declaration/function_decl.dart';
import '../ast/declaration/variable_decl.dart';
import '../ast/module.dart';
import '../ast/statement/statement.dart';
import '../ast/statement/statement_block.dart';
import '../ast/statement/statement_declaration.dart';
import '../ast/statement/statement_for.dart';
import '../ast/statement/statement_if.dart';
import '../ast/statement/statement_match.dart';
import '../ast/statement/statement_while.dart';
import '../ast/type/type.dart';
import '../ast/type/type_builtin.dart';
import '../ast/type/type_function.dart';
import '../ast/type/type_name.dart';
import '../ast/type/type_ref.dart';
import '../ast/type/type_array.dart';
import '../cli/builder.dart';
import '../cli/project.dart';

// ── LSP completion item kinds ─────────────────────────────────────────────────

const _kindFunction   = 3;
const _kindVariable   = 6;
const _kindClass      = 7;
const _kindEnum       = 13;
const _kindKeyword    = 14;
const _kindEnumMember = 20;
const _kindConstant   = 21;

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

  /// Serializes async dispatches so stdout writes never overlap.
  var _pendingDispatch = Future<void>.value();

  // ── entry point ─────────────────────────────────────────────────────────────

  Future<void> run() {
    final buffer   = <int>[];
    final completer = Completer<void>();
    stdin.listen(
      (chunk) {
        buffer.addAll(chunk);
        while (true) {
          final msg = _tryReadMessage(buffer);
          if (msg == null) break;
          _pendingDispatch = _pendingDispatch
              .then((_) => _dispatch(msg))
              .catchError((Object e, StackTrace st) {
            stderr.writeln('[mpd-lsp] dispatch error: $e\n$st');
          });
        }
      },
      onDone: completer.complete,
      onError: (Object e) => completer.completeError(e),
      cancelOnError: true,
    );
    return completer.future;
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
    final bodyBytes   = utf8.encode(jsonEncode(msg));
    final headerBytes = utf8.encode('Content-Length: ${bodyBytes.length}\r\n\r\n');
    stdout.add(headerBytes);
    stdout.add(bodyBytes);
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
      case 'textDocument/signatureHelp':
        _respond(id, _handleSignatureHelp(params));
      case 'textDocument/hover':
        _respond(id, _handleHover(params));
      case 'textDocument/definition':
        _respond(id, _handleDefinition(params));
      default:
        if (id != null) _respondError(id, -32601, 'Method not found: $method');
    }
    await stdout.flush();
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
          'triggerCharacters': ['_', ':', '.'],
        },
        'signatureHelpProvider': {
          'triggerCharacters': ['(', ','],
        },
        'hoverProvider': true,
        'definitionProvider': true,
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
    late final LspAnalysis analysis;
    try {
      analysis = await Builder(project, target).analyzeForLsp();
    } catch (e, st) {
      stderr.writeln('[mpd-lsp] analyzeForLsp error: $e\n$st');
      return;
    }
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

    // Import member completion: `import some.module::<prefix>`
    final content = _openFiles[uri];
    if (content != null) {
      final lines = content.split('\n');
      if (line < lines.length) {
        final linePrefix = lines[line].substring(0, char.clamp(0, lines[line].length));
        final importMatch = RegExp(r'^import\s+([\w.]+)::([\w*]*)$').firstMatch(linePrefix);
        if (importMatch != null) {
          final modPath    = importMatch.group(1)!;
          final memPrefix  = importMatch.group(2)!;
          return {'isIncomplete': false, 'items': _importItems(modPath, memPrefix)};
        }
      }
    }

    // Member access completion: `obj.prefix` or `EnumName.prefix`
    if (content != null) {
      final lines = content.split('\n');
      if (line < lines.length) {
        final linePrefix = lines[line].substring(0, char.clamp(0, lines[line].length));
        final memberMatch = RegExp(r'([\w]+)\.([\w]*)$').firstMatch(linePrefix);
        if (memberMatch != null) {
          final objName   = memberMatch.group(1)!;
          final memPrefix = memberMatch.group(2)!;
          final members   = _memberItems(uri, line, char, objName, memPrefix);
          if (members != null) {
            return {'isIncomplete': false, 'items': members};
          }
        }
      }
    }

    final prefix = _prefixAt(uri, line, char);
    final locals = _localsAt(uri, line, char);
    final items  = _completionItems(prefix, locals: locals);
    return {'isIncomplete': false, 'items': items};
  }

  /// Extract the identifier prefix the user is currently typing.
  // ── signature help ───────────────────────────────────────────────────────────

  Map<String, dynamic>? _handleSignatureHelp(Map<String, dynamic> params) {
    final uri      = (params['textDocument'] as Map)['uri'] as String;
    final position = params['position'] as Map<String, dynamic>;
    final line     = position['line'] as int;
    final char     = position['character'] as int;

    final content = _openFiles[uri];
    if (content == null) return null;

    // Find the function name and active parameter index from text before cursor.
    final (fnName, activeParam) = _callContextAt(content, line, char);
    if (fnName == null) return null;

    // Find the function declaration in loaded modules.
    for (final mod in _modules) {
      for (final fn in mod.functions) {
        if (fn.name != fnName || !fn.isPublic) continue;
        final params = fn.parameters
            .map((p) => '${p.name}: ${_typeStr(p.type)}')
            .toList();
        final label = 'fun $fnName(${params.join(', ')})${fn.returnType != null ? ' ${_typeStr(fn.returnType!)}' : ''}';

        // Build parameter spans — needed for VS Code to highlight active param.
        final paramInfos = <Map<String, dynamic>>[];
        int offset = 'fun $fnName('.length;
        for (int i = 0; i < params.length; i++) {
          paramInfos.add({'label': [offset, offset + params[i].length]});
          offset += params[i].length + (i < params.length - 1 ? 2 : 0); // +2 for ", "
        }

        return {
          'signatures': [
            {
              'label': label,
              'parameters': paramInfos,
            }
          ],
          'activeSignature': 0,
          'activeParameter': activeParam.clamp(0, (fn.parameters.length - 1).clamp(0, 99)),
        };
      }
    }
    return null;
  }

  /// Scan backwards from [line]:[char] to find the enclosing function call name
  /// and the index of the current argument (counting commas).
  (String?, int) _callContextAt(String content, int line, int char) {
    final lines = content.split('\n');
    if (line >= lines.length) return (null, 0);

    // Build a flat string from start of line up to cursor.
    final text = lines[line].substring(0, char.clamp(0, lines[line].length));

    // Walk backwards to find the opening '(' that isn't closed.
    int depth      = 0;
    int commas     = 0;
    for (int i = text.length - 1; i >= 0; i--) {
      final ch = text[i];
      if (ch == ')') { depth++; continue; }
      if (ch == '(') {
        if (depth > 0) { depth--; continue; }
        // Found the opening paren — read the function name before it.
        int nameEnd = i;
        while (nameEnd > 0 && text[nameEnd - 1] == ' ') { nameEnd--; }
        int nameStart = nameEnd;
        while (nameStart > 0 && _isIdentChar(text[nameStart - 1])) { nameStart--; }
        final name = text.substring(nameStart, nameEnd);
        return (name.isEmpty ? null : name, commas);
      }
      if (ch == ',' && depth == 0) commas++;
    }
    return (null, 0);
  }

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

  // ── hover ────────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _handleHover(Map<String, dynamic> params) {
    final uri  = (params['textDocument'] as Map)['uri'] as String;
    final pos  = params['position'] as Map<String, dynamic>;
    final word = _wordAt(uri, pos['line'] as int, pos['character'] as int);
    if (word.isEmpty) return null;

    for (final mod in _modules) {
      for (final fn in mod.functions) {
        if (fn.name != word || !fn.isPublic) continue;
        final ps  = fn.parameters.map((p) => '${p.name}: ${_typeStr(p.type)}').join(', ');
        final ret = fn.returnType != null ? ' ${_typeStr(fn.returnType!)}' : '';
        return {
          'contents': {'kind': 'markdown', 'value': '```mpd\nfun $word($ps)$ret\n```'},
        };
      }
      for (final v in mod.variables) {
        if (v.name != word || !v.isPublic) continue;
        final kw   = v.isConst ? 'const' : (v.isMutable ? 'var' : 'val');
        final type = v.type != null ? ': ${_typeStr(v.type!)}' : '';
        return {
          'contents': {'kind': 'markdown', 'value': '```mpd\n$kw $word$type\n```'},
        };
      }
      for (final cls in mod.classes) {
        if (cls.name != word || !cls.isPublic) continue;
        return {
          'contents': {'kind': 'markdown', 'value': '```mpd\nclass $word\n```'},
        };
      }
      for (final enm in mod.enums) {
        if (enm.name != word || !enm.isPublic) continue;
        final members = enm.members.map((m) => m.name).join(', ');
        return {
          'contents': {'kind': 'markdown', 'value': '```mpd\nenum $word { $members }\n```'},
        };
      }
    }
    return null;
  }

  // ── go-to-definition ─────────────────────────────────────────────────────────

  Map<String, dynamic>? _handleDefinition(Map<String, dynamic> params) {
    final uri  = (params['textDocument'] as Map)['uri'] as String;
    final pos  = params['position'] as Map<String, dynamic>;
    final word = _wordAt(uri, pos['line'] as int, pos['character'] as int);
    if (word.isEmpty) return null;

    for (final mod in _modules) {
      // Skip pseudo-modules.
      if (mod.path.startsWith(r'$')) continue;

      int? declPos;
      for (final fn  in mod.functions) { if (fn.name  == word) { declPos = fn.position;  break; } }
      for (final v   in mod.variables) { if (v.name   == word) { declPos = v.position;   break; } }
      for (final cls in mod.classes)   { if (cls.name == word) { declPos = cls.position; break; } }
      for (final enm in mod.enums)     { if (enm.name == word) { declPos = enm.position; break; } }

      if (declPos == null) continue;

      final (line, col) = mod.sourceFile.getLocation(declPos);
      return {
        'uri': _pathToUri(mod.sourceFile.name),
        'range': _range(line - 1, col - 1, line - 1, col - 1 + word.length),
      };
    }
    return null;
  }

  /// Extract the full identifier word at [line]:[character] (extends both directions).
  String _wordAt(String uri, int line, int character) {
    final content = _openFiles[uri];
    if (content == null) return '';
    final lines = content.split('\n');
    if (line >= lines.length) return '';
    final text = lines[line];
    final col  = character.clamp(0, text.length);
    int start = col;
    int end   = col;
    while (start > 0       && _isIdentChar(text[start - 1])) { start--; }
    while (end   < text.length && _isIdentChar(text[end]))   { end++;   }
    return text.substring(start, end);
  }

  bool _isIdentChar(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 65 && c <= 90) ||  // A-Z
           (c >= 97 && c <= 122) || // a-z
           (c >= 48 && c <= 57) ||  // 0-9
           c == 95;                  // _
  }

  /// Completion items for `obj.prefix` — resolves [objName]'s type then returns
  /// matching class fields/methods, or enum members if [objName] is an enum name.
  List<Map<String, dynamic>>? _memberItems(
      String uri, int line, int char, String objName, String prefix) {
    // 1. Resolve type of objName: check locals first, then module variables.
    Type? objType;
    final locals = _localsAt(uri, line, char);
    for (final (name, type) in locals) {
      if (name == objName) { objType = type; break; }
    }
    if (objType == null) {
      for (final mod in _modules) {
        for (final v in mod.variables) {
          if (v.name == objName) { objType = v.type; break; }
        }
        if (objType != null) break;
      }
    }

    // 2. Unwrap &T → T to get the base type name.
    final baseType = objType is TypeRef ? objType.elementType : objType;
    final className = baseType is TypeName ? baseType.name : null;

    // 3a. Class member access.
    if (className != null) {
      for (final mod in _modules) {
        for (final cls in mod.classes) {
          if (cls.name != className) continue;
          final items = <Map<String, dynamic>>[];
          for (final f in cls.constructorFields) {
            if (!f.name.startsWith(prefix)) continue;
            items.add({'label': f.name, 'kind': _kindVariable, 'detail': _typeStr(f.type)});
          }
          for (final f in cls.bodyFields) {
            if (!f.name.startsWith(prefix)) continue;
            final detail = f.type != null ? _typeStr(f.type!) : 'var';
            items.add({'label': f.name, 'kind': _kindVariable, 'detail': detail});
          }
          for (final m in cls.methods) {
            if (!m.isPublic) continue;
            if (!m.name.startsWith(prefix)) continue;
            items.add(_fnItem(m));
          }
          return items;
        }
      }
    }

    // 3b. Enum member access: `EnumName.prefix`
    for (final mod in _modules) {
      for (final enm in mod.enums) {
        if (enm.name != objName) continue;
        final items = <Map<String, dynamic>>[];
        for (final member in enm.members) {
          if (!member.name.startsWith(prefix)) continue;
          items.add({'label': member.name, 'kind': _kindEnumMember, 'detail': enm.name});
        }
        return items;
      }
    }

    return null;
  }

  /// Completion items for `import <modPath>::<prefix>` — lists public symbols
  /// from modules whose path matches [modPath], plus `*`.
  List<Map<String, dynamic>> _importItems(String modPath, String prefix) {
    final items = <Map<String, dynamic>>[];
    final seen  = <String>{};

    if ('*'.startsWith(prefix) && seen.add('*')) {
      items.add({'label': '*', 'kind': _kindKeyword, 'detail': 'import all'});
    }

    for (final mod in _modules) {
      if (mod.path != modPath) continue;

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

  List<Map<String, dynamic>> _completionItems(String prefix,
      {List<(String, Type?)> locals = const []}) {
    final items = <Map<String, dynamic>>[];
    final seen  = <String>{};

    // Local variables and parameters take priority (innermost scope first).
    for (final (name, type) in locals) {
      if (!name.startsWith(prefix)) continue;
      if (!seen.add(name)) continue;
      final detail = type != null ? _typeStr(type) : 'var';
      items.add({'label': name, 'kind': _kindVariable, 'detail': detail});
    }

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

  /// Returns locals (params + declared variables) visible in the function
  /// containing the cursor at [line]:[char] in [uri].
  List<(String, Type?)> _localsAt(String uri, int line, int char) {
    final content = _openFiles[uri];
    if (content == null) return [];

    // Cursor byte offset.
    final lines = content.split('\n');
    int offset = 0;
    for (int i = 0; i < line && i < lines.length; i++) {
      offset += lines[i].length + 1; // +1 for '\n'
    }
    offset += char.clamp(0, line < lines.length ? lines[line].length : 0);

    // Match URI to module by source file path.
    final filePath = Uri.parse(uri).toFilePath();
    for (final mod in _modules) {
      if (mod.sourceFile.name != filePath) continue;

      // Collect all functions (module-level + class methods) sorted by position.
      final allFns = <FunctionDecl>[
        ...mod.functions,
        for (final cls in mod.classes) ...cls.methods,
      ]..sort((a, b) => a.position.compareTo(b.position));

      // Find the last function whose start is at or before the cursor.
      FunctionDecl? enclosing;
      for (int i = 0; i < allFns.length; i++) {
        if (allFns[i].position > offset) break;
        final nextStart = i + 1 < allFns.length ? allFns[i + 1].position : content.length;
        if (offset <= nextStart) enclosing = allFns[i];
      }
      if (enclosing == null) return [];

      final result = <(String, Type?)>[];
      for (final p in enclosing.parameters) {
        result.add((p.name, p.type));
      }
      if (enclosing.body != null) _collectLocals(enclosing.body!, result);
      return result;
    }
    return [];
  }

  /// Recursively collect all [DeclarationStatement] names+types from [stmt].
  void _collectLocals(Statement stmt, List<(String, Type?)> out) {
    if (stmt is DeclarationStatement) {
      out.add((stmt.name, stmt.type));
    } else if (stmt is Block) {
      for (final s in stmt.statements) {
        _collectLocals(s, out);
      }
    } else if (stmt is IfStatement) {
      _collectLocals(stmt.body, out);
      if (stmt.else_ != null) _collectLocals(stmt.else_!, out);
    } else if (stmt is WhileStatement) {
      _collectLocals(stmt.body, out);
    } else if (stmt is ForRangeStatement) {
      out.add((stmt.variable, null));
      _collectLocals(stmt.body, out);
    } else if (stmt is ForInStatement) {
      out.add((stmt.item, null));
      if (stmt.index != null) out.add((stmt.index!, null));
      _collectLocals(stmt.body, out);
    } else if (stmt is MatchStatement) {
      for (final arm in stmt.arms) {
        _collectLocals(arm.body, out);
      }
    }
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
