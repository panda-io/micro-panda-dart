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

    // Named type (class or enum): Point, util.Color
    if (_current.type == TokenType.identifier) {
      final name = _expectIdentifier();
      if (_current.type == TokenType.dot) {
        _advance();
        final typeName = _expectIdentifier();
        return TypeName(typeName,
            qualifiedName: '$name.$typeName', position: pos);
      }
      return TypeName(name, position: pos);
    }

    _error('expected type, found ${_current.type.name}');
  }

  /// Wrap [base] in TypeArray if '[' follows. Supports multi-dimensional: T[M][N].
  Type _parseArraySuffix(Type base) {
    if (_current.type != TokenType.leftBracket) return base;
    final pos = base.position;
    final array = TypeArray(base, pos);
    while (_current.type == TokenType.leftBracket) {
      _advance(); // consume '['
      if (_current.type == TokenType.intLiteral) {
        final size = int.parse(_current.literal);
        _advance();
        array.dimension.add(size);
      } else {
        // Unsized dimension (e.g. slice / parameter passing)
        array.dimension.add(0);
      }
      _expect(TokenType.rightBracket);
    }
    return array;
  }
}
