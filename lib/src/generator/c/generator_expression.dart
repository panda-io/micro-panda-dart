part of 'generator.dart';

extension GeneratorExpression on CGenerator {
  // ── expression dispatch ───────────────────────────────────────────────────────

  String _expr(Expression expr) {
    if (expr is Literal)          return _literal(expr);
    if (expr is Identifier)       return _identifier(expr);
    if (expr is This)             return 'this';
    if (expr is Binary)           return _binary(expr);
    if (expr is Unary)            return '(${_unaryOpStr(expr.operator_)}${_expr(expr.expression)})';
    if (expr is Increment)        return '${_expr(expr.expression)}++';
    if (expr is Decrement)        return '${_expr(expr.expression)}--';
    if (expr is MemberAccess)     return _memberAccess(expr);
    if (expr is Subscript)        return _subscript(expr);
    if (expr is Invocation)       return _invocation(expr);
    if (expr is RefExpression)    return '(&${_expr(expr.expression)})';
    if (expr is Conversion)       return _conversion(expr);
    if (expr is Sizeof)           return _sizeof(expr);
    if (expr is ArrayInitializer) return _arrayInit(expr);
    return '/* unknown expr */';
  }

  // ── primary helpers ───────────────────────────────────────────────────────────

  String _literal(Literal lit) {
    final isFixed = lit.type is TypeBuiltin &&
        (lit.type as TypeBuiltin).token == TokenType.typeFixed;
    return switch (lit.tokenType) {
      TokenType.typeNull      => 'NULL',
      TokenType.boolLiteral   => lit.value,
      TokenType.charLiteral   => "'${lit.value}'",
      TokenType.stringLiteral => '(__Slice_uint8_t){(uint8_t*)"${lit.value}", sizeof("${lit.value}") - 1}',
      TokenType.floatLiteral  => isFixed
          ? '${(double.parse(lit.value) * 65536.0).round()}'
          : '${lit.value}f',
      TokenType.intLiteral    => isFixed
          ? '${int.parse(lit.value) << 16}'
          : lit.value,
      _                       => lit.value,
    };
  }

  bool _isFixedExpr(Expression e) =>
      e.type is TypeBuiltin &&
      (e.type as TypeBuiltin).token == TokenType.typeFixed;

  String _binary(Binary expr) {
    final op = expr.operator_;
    if (_isFixedExpr(expr.left) && _isFixedExpr(expr.right)) {
      final l = _expr(expr.left);
      final r = _expr(expr.right);
      if (op == TokenType.mul) {
        return '((int32_t)(((int64_t)($l) * ($r)) >> 16))';
      }
      if (op == TokenType.div) {
        return '((int32_t)(((int64_t)($l) << 16) / ($r)))';
      }
    }
    return '(${_expr(expr.left)} ${_opStr(expr.operator_)} ${_expr(expr.right)})';
  }

  String _subscript(Subscript sub) {
    final parentType = _inferType(sub.parent);
    if (parentType is TypeArray && parentType.isSlice) {
      // Slice subscript: slice.ptr[i]
      return '${_expr(sub.parent)}.ptr[${_expr(sub.index)}]';
    }
    return '${_expr(sub.parent)}[${_expr(sub.index)}]';
  }

  String _sizeof(Sizeof expr) {
    // In a generic function body, sizeof<T>() → __sizeof_T (the hidden size param)
    if (expr.target is TypeName) {
      final name = (expr.target as TypeName).name!;
      if (_typeParams.contains(name)) return '__sizeof_$name';
    }
    return 'sizeof(${_cType(expr.target)})';
  }

  String _arrayInit(ArrayInitializer expr) {
    final elems = expr.elements.map(_expr).join(', ');
    // Slice literal {ptr, len} — always emit compound literal for correct C
    if (expr.isSliceLiteral && expr.type is TypeArray) {
      return '(${_cType(expr.type!)}){$elems}';
    }
    return '{$elems}';
  }

  String _conversion(Conversion expr) {
    final t = expr.targetType;
    // In a generic body, casting to a type param → void*
    if (t is TypeRef &&
        t.elementType is TypeName &&
        _typeParams.contains((t.elementType as TypeName).name)) {
      return '(void*)(${_expr(expr.value)})';
    }
    return '((${_cType(t)})(${_expr(expr.value)}))';
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
    // Global variable reference → use namespaced C name.
    if (!_scope.containsKey(id.name)) {
      final cName = _localVarMap[id.name];
      if (cName != null) return cName;
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

      // Check if receiver is a module qualifier (e.g. `io.print_str()`).
      if (ma.parent is Identifier) {
        final receiverName = (ma.parent as Identifier).name;
        if (_qualifierToModPath.containsKey(receiverName)) {
          final modPath = _qualifierToModPath[receiverName]!;
          final cName = _cFnName(modPath, ma.member);
          return _callByCName(cName, inv.arguments, inv.typeArgs);
        }
      }

      // Built-in .size() on arrays/slices
      if (ma.member == 'size' && inv.arguments.isEmpty) {
        final receiverType = _inferType(ma.parent);
        if (receiverType is TypeArray) {
          if (receiverType.isSlice) {
            return '${_expr(ma.parent)}.size'; // slice fat-pointer field
          } else if (receiverType.isFixed) {
            return '${receiverType.dimension[0]}'; // compile-time constant
          }
        }
      }

      return _methodCall(ma.parent, ma.member, inv.arguments, inv.typeArgs);
    }

    if (inv.function is Identifier) {
      final name = (inv.function as Identifier).name;
      // @extern function → apply template substitution
      if (_externFns.containsKey(name)) {
        return _applyExtern(_externFns[name]!, inv.arguments);
      }
      // Class constructor call in expression position: VM() → {0}
      if (_classes.containsKey(name)) return '{0}';
      // Resolve to namespaced C name via per-module call map.
      final cName = _localCallMap[name];
      if (cName != null) return _callByCName(cName, inv.arguments, inv.typeArgs);
    }

    // Fallback: emit as-is (e.g. function pointer calls, unresolved names).
    final fn = _expr(inv.function);
    final regularArgs = inv.arguments.map(_expr).join(', ');
    final sizeofArgs = inv.typeArgs.map((t) => 'sizeof(${_cType(t)})').join(', ');
    final allArgs = [
      if (regularArgs.isNotEmpty) regularArgs,
      if (sizeofArgs.isNotEmpty) sizeofArgs,
    ].join(', ');
    final call = '$fn($allArgs)';

    // Cast return value when type args present
    if (inv.typeArgs.length == 1) return '(${_cType(inv.typeArgs.first)}*)$call';
    return call;
  }

  /// Emit a call to a function whose C name is already known.
  String _callByCName(String cName, List<Expression> args, List<Type> typeArgs) {
    final regularArgs = args.map(_expr).join(', ');
    final sizeofArgs = typeArgs.map((t) => 'sizeof(${_cType(t)})').join(', ');
    final allArgs = [
      if (regularArgs.isNotEmpty) regularArgs,
      if (sizeofArgs.isNotEmpty) sizeofArgs,
    ].join(', ');
    final call = '$cName($allArgs)';
    if (typeArgs.length == 1) return '(${_cType(typeArgs.first)}*)$call';
    return call;
  }

  /// Emit a call to an @extern function using its template.
  ///
  ///   @extern                       → fn_name(args...)
  ///   @extern("malloc")             → malloc(args...)
  ///   @extern("assert({a} == {b})") → assert(x == y)
  String _applyExtern(FunctionDecl fn, List<Expression> callArgs) {
    final template = fn.externAnnotation!.template;
    final args = callArgs.map(_expr).toList();

    if (template == null) {
      // No template: call by the function's own name
      return '${fn.name}(${args.join(', ')})';
    }
    if (!template.contains('{')) {
      // C rename (no placeholders): pass args in order
      return '$template(${args.join(', ')})';
    }
    // Named placeholder substitution: {paramName} → evaluated arg expression
    var result = template;
    for (int i = 0; i < fn.parameters.length && i < args.length; i++) {
      result = result.replaceAll('{${fn.parameters[i].name}}', args[i]);
    }
    return result;
  }

  String _methodCall(Expression receiver, String method, List<Expression> args,
      [List<Type> typeArgs = const []]) {
    final type = _inferType(receiver);
    final argsStr = args.map(_expr).join(', ');
    final sizeofArgs = typeArgs.map((t) => 'sizeof(${_cType(t)})').join(', ');

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

    final allArgs = [
      receiverArg,
      if (argsStr.isNotEmpty) argsStr,
      if (sizeofArgs.isNotEmpty) sizeofArgs,
    ].join(', ');
    final call = '${className}_$method($allArgs)';

    // Cast return value when type args present
    if (typeArgs.length == 1) return '(${_cType(typeArgs.first)}*)$call';
    return call;
  }

  // ── type inference ────────────────────────────────────────────────────────────

  /// Infer the type of [expr] from the current scope (best-effort).
  Type? _inferType(Expression expr) {
    if (expr is Identifier) {
      if (_scope.containsKey(expr.name)) return _scope[expr.name];
      if (_globals.containsKey(expr.name)) return _globals[expr.name];
      // Check class fields (constructor + body fields)
      if (_currentClass != null) {
        final cls = _classes[_currentClass];
        if (cls != null) {
          for (final f in cls.constructorFields) {
            if (f.name == expr.name) return f.type;
          }
          for (final f in cls.bodyFields) {
            if (f.name == expr.name) return f.type;
          }
        }
      }
      return null;
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
