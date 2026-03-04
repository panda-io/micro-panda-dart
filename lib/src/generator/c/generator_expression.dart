part of 'generator.dart';

extension GeneratorExpression on CGenerator {
  // ── expression dispatch ───────────────────────────────────────────────────────

  String _expr(Expression expr) {
    if (expr is Literal)          return _literal(expr);
    if (expr is Identifier)       return _identifier(expr);
    if (expr is This)             return 'this';
    if (expr is Binary)           return '(${_expr(expr.left)} ${_opStr(expr.operator_)} ${_expr(expr.right)})';
    if (expr is Unary)            return '(${_unaryOpStr(expr.operator_)}${_expr(expr.expression)})';
    if (expr is Increment)        return '${_expr(expr.expression)}++';
    if (expr is Decrement)        return '${_expr(expr.expression)}--';
    if (expr is MemberAccess)     return _memberAccess(expr);
    if (expr is Subscript)        return '${_expr(expr.parent)}[${_expr(expr.index)}]';
    if (expr is Invocation)       return _invocation(expr);
    if (expr is RefExpression)    return '(&${_expr(expr.expression)})';
    if (expr is Conversion)       return '((${_cType(expr.targetType)})(${_expr(expr.value)}))';
    if (expr is Sizeof)           return 'sizeof(${_cType(expr.target)})';
    if (expr is ArrayInitializer) return '{${expr.elements.map(_expr).join(', ')}}';
    return '/* unknown expr */';
  }

  // ── primary helpers ───────────────────────────────────────────────────────────

  String _literal(Literal lit) {
    return switch (lit.tokenType) {
      TokenType.boolLiteral   => lit.value,
      TokenType.charLiteral   => "'${lit.value}'",
      TokenType.stringLiteral => '"${lit.value}"',
      TokenType.floatLiteral  => '${lit.value}f',
      _                       => lit.value, // int literals
    };
  }

  String _identifier(Identifier id) {
    // Inside a member function, bare field names become this->field.
    if (_currentClass != null && !_scope.containsKey(id.name)) {
      final cls = _classes[_currentClass];
      if (cls != null) {
        final isField = cls.constructorFields.any((f) => f.name == id.name) ||
                        cls.bodyFields.any((f) => f.name == id.name);
        if (isField) return 'this->${id.name}';
      }
    }
    return id.name;
  }

  String _memberAccess(MemberAccess ma) {
    // Enum member: Color.Red → Color_Red
    if (ma.parent is Identifier) {
      final name = (ma.parent as Identifier).name;
      if (_enums.containsKey(name)) return '${name}_${ma.member}';
    }
    // Pointer vs value member access
    final type = _inferType(ma.parent);
    final recv = _expr(ma.parent);
    if (type is TypeRef) return '$recv->${ma.member}';
    return '$recv.${ma.member}';
  }

  String _invocation(Invocation inv) {
    // Method call: receiver.method(args) → ClassName_method(ref, args)
    if (inv.function is MemberAccess) {
      final ma = inv.function as MemberAccess;
      return _methodCall(ma.parent, ma.member, inv.arguments);
    }

    if (inv.function is Identifier) {
      final name = (inv.function as Identifier).name;
      // @extern function → apply template substitution
      if (_externFns.containsKey(name)) {
        return _applyExtern(_externFns[name]!, inv.arguments);
      }
      // Class constructor call in expression position: VM() → {0}
      if (_classes.containsKey(name)) return '{0}';
    }

    // Regular function call
    final fn = _expr(inv.function);
    final args = inv.arguments.map(_expr).join(', ');
    return '$fn($args)';
  }

  /// Emit a call to an @extern function using its template.
  ///
  ///   @extern                      → fn_name(args...)
  ///   @extern("malloc")            → malloc(args...)
  ///   @extern("assert($a == $b)")  → assert(x == y)
  String _applyExtern(FunctionDecl fn, List<Expression> callArgs) {
    final template = fn.externAnnotation!.template;
    final args = callArgs.map(_expr).toList();

    if (template == null) {
      // No template: call by the function's own name
      return '${fn.name}(${args.join(', ')})';
    }
    if (!template.contains('\$')) {
      // C rename (no placeholders): pass args in order
      return '$template(${args.join(', ')})';
    }
    // Named placeholder substitution: $paramName → evaluated arg expression
    var result = template;
    for (int i = 0; i < fn.parameters.length && i < args.length; i++) {
      result = result.replaceAll('\$${fn.parameters[i].name}', args[i]);
    }
    return result;
  }

  String _methodCall(Expression receiver, String method, List<Expression> args) {
    final type = _inferType(receiver);
    final argsStr = args.map(_expr).join(', ');

    String? className;
    String receiverArg;

    if (type is TypeRef && type.elementType is TypeName) {
      // Already a pointer
      className = (type.elementType as TypeName).name;
      receiverArg = _expr(receiver);
    } else if (type is TypeName && _classes.containsKey(type.name)) {
      // Value type — take address
      className = type.name;
      receiverArg = '(&${_expr(receiver)})';
    } else if (receiver is This) {
      className = _currentClass;
      receiverArg = 'this';
    } else {
      // Can't resolve — emit as plain call
      final recv = _expr(receiver);
      return argsStr.isEmpty ? '$recv.$method()' : '$recv.$method($argsStr)';
    }

    if (className == null) {
      final recv = _expr(receiver);
      return argsStr.isEmpty ? '$recv.$method()' : '$recv.$method($argsStr)';
    }

    final allArgs =
        argsStr.isEmpty ? receiverArg : '$receiverArg, $argsStr';
    return '${className}_$method($allArgs)';
  }

  // ── type inference ────────────────────────────────────────────────────────────

  /// Infer the type of [expr] from the current scope (best-effort).
  Type? _inferType(Expression expr) {
    if (expr is Identifier) {
      return _scope[expr.name] ?? _globals[expr.name];
    }
    if (expr is This && _currentClass != null) {
      return TypeRef(TypeName(_currentClass!));
    }
    return null;
  }

  // ── operator strings ──────────────────────────────────────────────────────────

  String _opStr(TokenType op) => switch (op) {
    TokenType.plus              => '+',
    TokenType.minus             => '-',
    TokenType.mul               => '*',
    TokenType.div               => '/',
    TokenType.rem               => '%',
    TokenType.bitAnd            => '&',
    TokenType.bitOr             => '|',
    TokenType.bitXor            => '^',
    TokenType.leftShift         => '<<',
    TokenType.rightShift        => '>>',
    TokenType.equal             => '==',
    TokenType.notEqual          => '!=',
    TokenType.less              => '<',
    TokenType.greater           => '>',
    TokenType.lessEqual         => '<=',
    TokenType.greaterEqual      => '>=',
    TokenType.and               => '&&',
    TokenType.or                => '||',
    TokenType.assign            => '=',
    TokenType.plusAssign        => '+=',
    TokenType.minusAssign       => '-=',
    TokenType.mulAssign         => '*=',
    TokenType.divAssign         => '/=',
    TokenType.remAssign         => '%=',
    TokenType.xorAssign         => '^=',
    TokenType.andAssign         => '&=',
    TokenType.orAssign          => '|=',
    TokenType.leftShiftAssign   => '<<=',
    TokenType.rightShiftAssign  => '>>=',
    _                           => '/*?*/',
  };

  String _unaryOpStr(TokenType op) => switch (op) {
    TokenType.minus      => '-',
    TokenType.not        => '!',
    TokenType.complement => '~',
    _                    => '/*?*/',
  };
}
