part of 'parser.dart';

extension ParserModule on Parser {
  Module _parseModule(String path) {
    final includes = <String>[];
    final imports = <Import>[];
    final variables = <VariableDecl>[];
    final functions = <FunctionDecl>[];
    final classes = <ClassDecl>[];
    final enums = <EnumDecl>[];

    _skipNewlines();

    // imports come first
    while (_current.type == TokenType.kImport) {
      imports.add(_parseImport());
      _skipNewlines();
    }

    // top-level declarations
    while (_current.type != TokenType.eof) {
      _skipNewlines();
      if (_current.type == TokenType.eof) break;

      final allAnnotations = _parseAnnotations();

      // Extract @include("header") — can appear before any declaration
      final annotations = <Annotation>[];
      for (final a in allAnnotations) {
        if (a.name == 'include' && a.template != null) {
          includes.add(a.template!);
        } else {
          annotations.add(a);
        }
      }

      // @include may appear standalone (no following declaration)
      if (_current.type == TokenType.eof) break;

      switch (_current.type) {
        case TokenType.kVar:
        case TokenType.kVal:
        case TokenType.kConst:
          if (annotations.isNotEmpty) {
            _error('annotations are not supported on variable declarations');
          }
          variables.add(_parseVariableDecl());
        case TokenType.kFunction:
          functions.add(_parseFunctionDecl(annotations: annotations));
        case TokenType.kClass:
          if (annotations.isNotEmpty) {
            _error('annotations are not supported on class declarations');
          }
          classes.add(_parseClassDecl());
        case TokenType.kEnum:
          if (annotations.isNotEmpty) {
            _error('annotations are not supported on enum declarations');
          }
          enums.add(_parseEnumDecl());
        case TokenType.newline:
          break; // standalone @include with only newlines remaining
        default:
          _error('expected top-level declaration (var, val, const, fun, class, enum), '
              'found ${_current.type.name}');
      }
    }

    return Module(path, file, includes, imports, variables, functions, classes, enums);
  }

  Import _parseImport() {
    final pos = _current.offset;
    _expect(TokenType.kImport);

    // Parse dot-separated path: util.math
    var path = _expectIdentifier();
    while (_current.type == TokenType.dot) {
      _advance();
      path += '.${_expectIdentifier()}';
    }

    String? symbol;
    String? alias;

    // Optional symbol: ::min
    if (_current.type == TokenType.doubleColon) {
      _advance();
      symbol = _expectIdentifier();
    }

    // Optional alias: as m
    if (_current.type == TokenType.kAs) {
      _advance();
      alias = _expectIdentifier();
    }

    _expectNewline();
    return Import(path, symbol: symbol, alias: alias, position: pos);
  }

  String _expectIdentifier() {
    if (_current.type != TokenType.identifier) {
      _error('expected identifier, found ${_current.type.name}');
    }
    final name = _current.literal;
    _advance();
    return name;
  }
}
