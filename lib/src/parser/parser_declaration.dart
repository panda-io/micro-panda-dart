part of 'parser.dart';

extension ParserDeclaration on Parser {
  // ── variable / val / const ──────────────────────────────────────────────────

  VariableDecl _parseVariableDecl() {
    final pos = _current.offset;
    final keyword = _current.type; // kVar, kVal, kConst
    _advance();

    final name = _expectIdentifier();

    // const must use '= value' (no type inference)
    if (keyword == TokenType.kConst) {
      _expect(TokenType.assign);
      final value = _parseExpression();
      _expectNewline();
      return VariableDecl(keyword, name, null, value, pos);
    }

    // var/val: either 'name: Type = value' or 'name := expr'
    if (_current.type == TokenType.inferAssign) {
      _advance();
      final value = _parseExpression();
      _expectNewline();
      return VariableDecl(keyword, name, null, value, pos);
    }

    // explicit type annotation
    _expect(TokenType.colon);
    final type = _parseType();

    if (_current.type == TokenType.assign) {
      _advance();
      final value = _parseExpression();
      _expectNewline();
      return VariableDecl(keyword, name, type, value, pos);
    }

    _expectNewline();
    return VariableDecl(keyword, name, type, null, pos);
  }

  // ── function ────────────────────────────────────────────────────────────────

  FunctionDecl _parseFunctionDecl({List<Annotation> annotations = const []}) {
    final pos = _current.offset;
    _expect(TokenType.kFunction);

    final name = _expectIdentifier();

    // Optional generic type params: fun f<T, U>(...)
    final typeParams = <String>[];
    if (_current.type == TokenType.less) {
      _advance(); // consume '<'
      typeParams.add(_expectIdentifier());
      while (_current.type == TokenType.comma) {
        _advance();
        typeParams.add(_expectIdentifier());
      }
      _expect(TokenType.greater);
    }

    final params = _parseParameters();

    // optional `: ` before return type (Kotlin-style; also accepted without colon)
    if (_current.type == TokenType.colon) _advance();

    // optional return type (if next is not newline/eof/dedent)
    final returnType = _current.type != TokenType.newline &&
            _current.type != TokenType.eof &&
            _current.type != TokenType.dedent
        ? _parseType()
        : null;

    // optional body
    Block? body;
    if (_current.type == TokenType.newline) {
      // peek: is there an indent next?
      _advance(); // consume newline
      if (_current.type == TokenType.indent) {
        body = _parseBlock();
      }
      // no indent → declaration only (no newline to consume again)
    } else {
      _expectNewline();
    }

    return FunctionDecl(name, params, returnType, body, pos,
        annotations: annotations, typeParams: typeParams);
  }

  List<Parameter> _parseParameters() {
    _expect(TokenType.leftParen);
    final params = <Parameter>[];
    if (_current.type == TokenType.rightParen) {
      _advance();
      return params;
    }
    params.add(_parseParameter());
    while (_current.type == TokenType.comma) {
      _advance();
      params.add(_parseParameter());
    }
    _expect(TokenType.rightParen);
    return params;
  }

  Parameter _parseParameter() {
    final pos = _current.offset;
    final name = _expectIdentifier();
    _expect(TokenType.colon);
    final type = _parseType();
    return Parameter(name, type, pos);
  }

  // ── class ───────────────────────────────────────────────────────────────────

  ClassDecl _parseClassDecl() {
    final pos = _current.offset;
    _expect(TokenType.kClass);
    final name = _expectIdentifier();

    // optional generic type params: class Foo<T, U>
    final typeParams = <String>[];
    if (_current.type == TokenType.less) {
      _advance();
      typeParams.add(_expectIdentifier());
      while (_current.type == TokenType.comma) {
        _advance();
        typeParams.add(_expectIdentifier());
      }
      _expect(TokenType.greater);
    }

    // constructor fields in (...)
    final constructorFields = _parseConstructorFields();

    // body: fields + methods, indented
    final bodyFields = <BodyField>[];
    final methods = <FunctionDecl>[];

    if (_current.type == TokenType.newline) {
      _advance();
      _skipNewlines(); // skip any blank lines between header and body
      if (_current.type == TokenType.indent) {
        _advance(); // consume indent
        _skipNewlines();
        while (_current.type != TokenType.dedent && _current.type != TokenType.eof) {
          if (_current.type == TokenType.kVar || _current.type == TokenType.kVal) {
            bodyFields.add(_parseBodyField());
          } else if (_current.type == TokenType.annotation ||
              _current.type == TokenType.kFunction) {
            final annots = _parseAnnotations();
            methods.add(_parseFunctionDecl(annotations: annots));
          } else {
            _error('expected field (var/val) or method (fun) in class body, '
                'found ${_current.type.name}');
          }
          _skipNewlines();
        }
        _expectDedent();
      }
    } else {
      _expectNewline();
    }

    return ClassDecl(name, constructorFields, bodyFields, methods, pos,
        typeParams: typeParams);
  }

  List<ClassField> _parseConstructorFields() {
    if (_current.type != TokenType.leftParen) return [];
    _advance();
    final fields = <ClassField>[];
    if (_current.type == TokenType.rightParen) {
      _advance();
      return fields;
    }
    fields.add(_parseConstructorField());
    while (_current.type == TokenType.comma) {
      _advance();
      fields.add(_parseConstructorField());
    }
    _expect(TokenType.rightParen);
    return fields;
  }

  ClassField _parseConstructorField() {
    final pos = _current.offset;
    if (_current.type != TokenType.kVal && _current.type != TokenType.kVar) {
      _error('expected val or var in constructor parameter');
    }
    final keyword = _current.type;
    _advance();
    final name = _expectIdentifier();
    _expect(TokenType.colon);
    final type = _parseType();
    return ClassField(keyword, name, type, null, pos);
  }

  BodyField _parseBodyField() {
    final pos = _current.offset;
    final keyword = _current.type;
    _advance();
    final name = _expectIdentifier();

    if (_current.type == TokenType.inferAssign) {
      _advance();
      final value = _parseExpression();
      _expectNewline();
      return BodyField(keyword, name, null, value, pos);
    }

    _expect(TokenType.colon);
    final type = _parseType();

    if (_current.type == TokenType.assign) {
      _advance();
      final value = _parseExpression();
      _expectNewline();
      return BodyField(keyword, name, type, value, pos);
    }

    _expectNewline();
    return BodyField(keyword, name, type, null, pos);
  }

  // ── enum ────────────────────────────────────────────────────────────────────

  EnumDecl _parseEnumDecl() {
    final pos = _current.offset;
    _expect(TokenType.kEnum);
    final name = _expectIdentifier();
    _expectNewline();
    _expectIndent();
    _skipNewlines();

    final members = <EnumMember>[];
    while (_current.type != TokenType.dedent && _current.type != TokenType.eof) {
      members.add(_parseEnumMember());
      _skipNewlines();
    }

    _expectDedent();
    return EnumDecl(name, members, pos);
  }

  EnumMember _parseEnumMember() {
    final pos = _current.offset;
    final name = _expectIdentifier();

    // tagged enum: Name(field: Type, ...)
    if (_current.type == TokenType.leftParen) {
      _advance();
      final fields = <Parameter>[];
      if (_current.type != TokenType.rightParen) {
        fields.add(_parseParameter());
        while (_current.type == TokenType.comma) {
          _advance();
          fields.add(_parseParameter());
        }
      }
      _expect(TokenType.rightParen);
      _expectNewline();
      return EnumMember(name, fields: fields, position: pos);
    }

    // value enum: Name = expr
    if (_current.type == TokenType.assign) {
      _advance();
      final value = _parseExpression();
      _expectNewline();
      return EnumMember(name, value: value, position: pos);
    }

    // plain enum
    _expectNewline();
    return EnumMember(name, position: pos);
  }
}
