part of 'generator.dart';

extension GeneratorStatement on CGenerator {
  // ── block ─────────────────────────────────────────────────────────────────────

  /// Emit the statements of a block at one extra indent level.
  /// Does NOT emit surrounding braces — the caller does that.
  void _emitBlock(Block block) {
    _indent++;
    for (final s in block.statements) {
      _emitStatement(s);
    }
    _indent--;
  }

  /// Emit the body of a control structure (if/while/for).
  /// Handles both Block and single-statement bodies.
  void _emitBody(Statement body) {
    if (body is Block) {
      _emitBlock(body);
    } else {
      _indent++;
      _emitStatement(body);
      _indent--;
    }
  }

  // ── statement dispatch ────────────────────────────────────────────────────────

  void _emitStatement(Statement stmt) {
    if (stmt is IfStatement) {
      _emitIf(stmt);
    } else if (stmt is WhileStatement) {
      _line('while (${_expr(stmt.condition)}) {');
      _emitBody(stmt.body);
      _line('}');
    } else if (stmt is ForRangeStatement) {
      _emitForRange(stmt);
    } else if (stmt is ForInStatement) {
      _emitForIn(stmt);
    } else if (stmt is MatchStatement) {
      _emitMatch(stmt);
    } else if (stmt is ReturnStatement) {
      _line(stmt.value != null ? 'return ${_expr(stmt.value!)};' : 'return;');
    } else if (stmt is BreakStatement) {
      _line('break;');
    } else if (stmt is ContinueStatement) {
      _line('continue;');
    } else if (stmt is DeclarationStatement) {
      _emitLocalDecl(stmt);
    } else if (stmt is ExpressionStatement) {
      _line('${_expr(stmt.expression)};');
    } else if (stmt is Block) {
      // Nested bare block (unusual but valid)
      _line('{');
      _emitBlock(stmt);
      _line('}');
    }
  }

  // ── if / else ─────────────────────────────────────────────────────────────────

  void _emitIf(IfStatement stmt) {
    _line('if (${_expr(stmt.condition)}) {');
    _emitBody(stmt.body);
    _emitElse(stmt.else_);
  }

  void _emitElse(Statement? else_) {
    if (else_ == null) {
      _line('}');
    } else if (else_ is IfStatement) {
      _line('} else if (${_expr(else_.condition)}) {');
      _emitBody(else_.body);
      _emitElse(else_.else_);
    } else {
      _line('} else {');
      _emitBody(else_);
      _line('}');
    }
  }

  // ── for range ─────────────────────────────────────────────────────────────────

  void _emitForRange(ForRangeStatement stmt) {
    final v = stmt.variable;
    final start = _expr(stmt.start);
    final end = _expr(stmt.end);
    _line('for (int32_t $v = $start; $v < $end; $v++) {');
    _emitBody(stmt.body);
    _line('}');
  }

  // ── for in ────────────────────────────────────────────────────────────────────

  void _emitForIn(ForInStatement stmt) {
    final iterType = _inferType(stmt.iterable);
    final iterable = _expr(stmt.iterable);

    // Determine element type and array length from the iterable's type.
    Type? elemType;
    String sizeExpr;
    if (iterType is TypeArray) {
      elemType = iterType.elementType;
      final dim = iterType.dimension.isNotEmpty ? iterType.dimension[0] : 0;
      sizeExpr = dim > 0
          ? '$dim'
          : '(sizeof($iterable) / sizeof(($iterable)[0]))';
    } else {
      // Unknown size: fall back to a 0 placeholder.
      sizeExpr = '0 /* TODO: array size */';
    }

    final idxVar = stmt.index ?? '_i';
    _line('for (size_t $idxVar = 0; $idxVar < $sizeExpr; $idxVar++) {');
    _indent++;
    _line('${_varDecl(stmt.item, elemType)} = $iterable[$idxVar];');
    // Track item and optional index in scope for the body.
    _scope[stmt.item] = elemType;
    if (stmt.index != null) _scope[stmt.index!] = TypeBuiltin(TokenType.typeUint64);
    // Emit body statements directly (avoid double-indent from _emitBody).
    if (stmt.body is Block) {
      for (final s in (stmt.body as Block).statements) {
        _emitStatement(s);
      }
    } else {
      _emitStatement(stmt.body);
    }
    _indent--;
    _line('}');
  }

  // ── match ─────────────────────────────────────────────────────────────────────

  void _emitMatch(MatchStatement stmt) {
    final hasDestructure = stmt.arms.any((a) => a.pattern is DestructurePattern);
    final matchExpr = _expr(stmt.expression);

    if (hasDestructure) {
      // Tagged-enum match: switch on the tag field.
      _line('switch (($matchExpr)->tag) {');
    } else {
      _line('switch ($matchExpr) {');
    }

    _indent++;
    for (final arm in stmt.arms) {
      _emitMatchArm(arm, matchExpr);
    }
    _indent--;
    _line('}');
  }

  void _emitMatchArm(MatchArm arm, String matchExpr) {
    final pat = arm.pattern;

    if (pat is WildcardPattern) {
      _line('default: {');
    } else if (pat is ExpressionPattern) {
      _line('case ${_caseExpr(pat.expression)}: {');
    } else if (pat is DestructurePattern) {
      final variant = _variants[pat.variantName];
      final enumName = variant?.enumName ?? '/* ? */';
      _line('case ${enumName}_${pat.variantName}: {');
      // Extract field bindings from the union data.
      if (variant != null) {
        final fields = variant.member.fields ?? [];
        _indent++;
        for (var i = 0; i < pat.bindings.length && i < fields.length; i++) {
          final binding = pat.bindings[i];
          final field = fields[i];
          _line('${_varDecl(binding, field.type)} = ($matchExpr)->data.${pat.variantName}.${field.name};');
          _scope[binding] = field.type;
        }
        _indent--;
      }
    }

    _indent++;
    // Emit body statements without extra braces.
    if (arm.body is Block) {
      for (final s in (arm.body as Block).statements) {
        _emitStatement(s);
      }
    } else {
      _emitStatement(arm.body);
    }
    _line('break;');
    _indent--;
    _line('}');
  }

  /// Emit an expression suitable as a `case` label.
  /// Enum member access X.Y → X_Y.
  String _caseExpr(Expression expr) {
    if (expr is MemberAccess && expr.parent is Identifier) {
      final parent = (expr.parent as Identifier).name;
      if (_enums.containsKey(parent)) return '${parent}_${expr.member}';
    }
    return _expr(expr);
  }

  // ── local declaration ─────────────────────────────────────────────────────────

  void _emitLocalDecl(DeclarationStatement stmt) {
    final isConst = stmt.keyword == TokenType.kConst || stmt.keyword == TokenType.kVal;
    final prefix = isConst ? 'const ' : '';

    // Resolve type: explicit type or infer from initializer.
    final type = stmt.type ?? _inferVarType(stmt.value);

    if (stmt.value != null) {
      _line('$prefix${_varDecl(stmt.name, type)} = ${_expr(stmt.value!)};');
    } else {
      _line('$prefix${_varDecl(stmt.name, type)};');
    }
    // Track for type lookups in the remainder of this scope.
    _scope[stmt.name] = type;
  }
}
