part of 'parser.dart';

extension ParserTypes on Parser {
  /// Parse a full type annotation.
  ///
  /// Grammar:
  ///   type      = '&' baseType ('[' size ']')* | baseType ('[' size ']')*
  ///   baseType  = scalar | namedType
  ///   namedType = identifier ('.' identifier)?
  Type _parseType() {
    final pos = _current.offset;

    // Function reference type: fun(T1, T2) RetType
    if (_current.type == TokenType.kFunction) {
      return _parseFunctionType(pos);
    }

    // Reference type: &T, &T[N]
    if (_current.type == TokenType.bitAnd) {
      _advance();
      final inner = _parseBaseType();
      final innerWithArray = _parseArraySuffix(inner);
      return TypeRef(innerWithArray, pos);
    }

    final base = _parseBaseType();
    return _parseArraySuffix(base);
  }

  /// Parse a scalar or named type (no ref, no array suffix).
  Type _parseBaseType() {
    final pos = _current.offset;

    // Scalar / builtin: bool, i8, u32, f32, void, ...
    if (_current.type.isScalar) {
      final token = _current.type;
      _advance();
      return TypeBuiltin(token, pos);
    }

    // Named type (class or enum): Point, util.Color, ArrayList<i32>
    if (_current.type == TokenType.identifier) {
      final name = _expectIdentifier();
      if (_current.type == TokenType.dot) {
        _advance();
        final typeName = _expectIdentifier();
        return TypeName(typeName,
            qualifiedName: '$name.$typeName', position: pos);
      }
      // optional generic type args: ArrayList<i32>, Map<K, V>
      if (_current.type == TokenType.less) {
        _advance();
        final typeArgs = <Type>[_parseTypeArg()];
        while (_current.type == TokenType.comma) {
          _advance();
          typeArgs.add(_parseTypeArg());
        }
        _expect(TokenType.greater);
        return TypeName(name, typeArgs: typeArgs, position: pos);
      }
      return TypeName(name, position: pos);
    }

    _error('expected type, found ${_current.type.name}');
  }

  /// Parse a single generic type argument and reject nesting.
  Type _parseTypeArg() {
    final t = _parseType();
    // Reject nested generics: ArrayList<ArrayList<i32>> is not supported.
    final inner = t is TypeRef ? t.elementType : t;
    if (inner is TypeName && inner.typeArgs.isNotEmpty) {
      _error('nested generic type arguments are not supported');
    }
    return t;
  }

  /// Parse `fun(T1, T2) RetType` as a TypeFunction.
  TypeFunction _parseFunctionType(int pos) {
    _advance(); // consume 'fun'
    _expect(TokenType.leftParen);
    final params = <Type>[];
    while (_current.type != TokenType.rightParen) {
      params.add(_parseType());
      if (_current.type == TokenType.comma) _advance();
    }
    _expect(TokenType.rightParen);
    final fn = TypeFunction(pos);
    fn.parameters = params;
    if (_isTypeStart()) {
      fn.returnTypes = [_parseType()];
    }
    return fn;
  }

  /// True if the current token can start a type annotation.
  bool _isTypeStart() {
    final t = _current.type;
    return t == TokenType.bitAnd ||
        t.isScalar ||
        t == TokenType.identifier ||
        t == TokenType.kFunction;
  }

  /// Wrap [base] in TypeArray if '[' follows.
  ///
  /// Leading slice suffix `[]` produces a nested TypeArray so that the element
  /// type is preserved correctly:
  ///   u8[]    → TypeArray(u8,   [0])          — slice
  ///   u8[8]   → TypeArray(u8,   [8])          — fixed array
  ///   u8[8][4]→ TypeArray(u8,   [8,4])        — flat 2-D fixed array
  ///   u8[][8] → TypeArray(TypeArray(u8,[0]), [8]) — fixed array of slices
  Type _parseArraySuffix(Type base) {
    if (_current.type != TokenType.leftBracket) return base;
    final pos = base.position;
    _advance(); // consume '['
    final int firstDim;
    Expression? firstDimExpr;
    if (_current.type == TokenType.intLiteral) {
      firstDim = int.parse(_current.literal);
      _advance();
    } else if (_current.type == TokenType.identifier) {
      // Constant expression as array size: Task[SYS_MAX_TASKS], Task[A + B], Task[A * B]
      firstDim = -1;
      firstDimExpr = _parseExpression();
    } else {
      firstDim = 0; // unsized / slice
    }
    _expect(TokenType.rightBracket);

    if (firstDim == 0) {
      // Leading [] — build TypeArray(base,[0]) then recurse so further [N]
      // suffixes wrap the slice rather than being added to the same flat list.
      final slice = TypeArray(base, pos)
        ..dimension.add(0)
        ..dimExprs.add(null);
      return _parseArraySuffix(slice);
    }

    // Fixed leading dimension — collect remaining fixed dims into flat list.
    final array = TypeArray(base, pos)
      ..dimension.add(firstDim)
      ..dimExprs.add(firstDimExpr);
    while (_current.type == TokenType.leftBracket) {
      _advance();
      if (_current.type == TokenType.intLiteral) {
        array.dimension.add(int.parse(_current.literal));
        array.dimExprs.add(null);
        _advance();
      } else if (_current.type == TokenType.identifier) {
        array.dimension.add(-1);
        array.dimExprs.add(_parseExpression());
      } else {
        array.dimension.add(0);
        array.dimExprs.add(null);
      }
      _expect(TokenType.rightBracket);
    }
    return array;
  }
}
