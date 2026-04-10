import '../ast/context.dart';
import '../ast/module.dart';
import '../ast/declaration/class_decl.dart';
import '../ast/declaration/function_decl.dart';
import '../ast/declaration/variable_decl.dart';
import '../ast/statement/statement.dart';
import '../ast/statement/statement_block.dart';
import '../ast/statement/statement_if.dart';
import '../ast/statement/statement_match.dart';
import '../ast/statement/statement_return.dart';
import '../ast/type/type.dart';
import '../ast/type/type_ref.dart';
import '../ast/type/type_name.dart';

/// Runs semantic validation over all modules.
/// Returns the list of [ValidationError]s found.
/// If the list is empty, the AST is well-typed and safe to generate.
class Validator {
  List<ValidationError> validate(
    List<Module> modules, {
    Map<String, Type?> configVars = const {},
  }) {
    final ctx = Context.root(modules, configVars: configVars);
    for (final mod in modules) {
      final modCtx = ctx.forModule(mod.sourceFile, mod.path);
      _checkModuleDuplicates(mod, modCtx);
      for (final v in mod.variables) {
        _validateGlobalVar(v, modCtx);
      }
      for (final fn in mod.functions) {
        _validateFunction(fn, null, modCtx);
      }
      for (final cls in mod.classes) {
        _validateClass(cls, modCtx);
      }
    }
    return ctx.errors;
  }

  /// Report duplicate top-level names within a single module.
  void _checkModuleDuplicates(Module mod, Context ctx) {
    final seen = <String, int>{};
    void check(String name, int pos) {
      if (seen.containsKey(name)) {
        ctx.error(pos, "duplicate declaration '$name'");
      } else {
        seen[name] = pos;
      }
    }
    for (final v in mod.variables) {
      check(v.name, v.position);
    }
    for (final fn in mod.functions) {
      check(fn.name, fn.position);
    }
    for (final cls in mod.classes) {
      check(cls.name, cls.position);
    }
    for (final enm in mod.enums) {
      check(enm.name, enm.position);
    }
  }

  void _validateGlobalVar(VariableDecl v, Context ctx) {
    if (v.value != null) {
      v.value!.validate(ctx, v.type);
    }
  }

  void _validateFunction(FunctionDecl fn, String? className, Context ctx) {
    if (fn.isExtern || fn.body == null) return;
    final fnCtx = ctx.forFunction(fn, className);
    if (className != null) {
      fnCtx.declare('this', TypeRef(TypeName(className)), fn.position);
    }
    // Collect all type params in scope (class + function level).
    final classTypeParams = className != null
        ? (ctx.classes[className]?.typeParams ?? const <String>[])
        : const <String>[];
    final allTypeParams = {...classTypeParams, ...fn.typeParams};
    for (final p in fn.parameters) {
      if (p.type is TypeName) {
        final tn = p.type as TypeName;
        final name = tn.name;
        if (name != null && !allTypeParams.contains(name) && ctx.classes.containsKey(name)) {
          ctx.error(p.position,
              "parameter '${p.name}' has class type '$name' — use a reference '&$name' instead");
        }
      }
      fnCtx.declare(p.name, p.type, p.position);
    }
    fn.body!.validate(fnCtx);
    // For non-void functions, ensure every code path returns a value.
    if (fn.returnType != null && !_alwaysReturns(fn.body!)) {
      ctx.error(fn.position,
          "function '${fn.name}' with return type '${Context.typeName(fn.returnType)}' does not always return a value");
    }
  }

  /// Returns true if [stmt] guarantees a return on every code path.
  bool _alwaysReturns(Statement stmt) {
    if (stmt is ReturnStatement) return true;
    if (stmt is Block) {
      return stmt.statements.isNotEmpty && _alwaysReturns(stmt.statements.last);
    }
    if (stmt is IfStatement) {
      return stmt.else_ != null &&
          _alwaysReturns(stmt.body) &&
          _alwaysReturns(stmt.else_!);
    }
    if (stmt is MatchStatement) {
      return stmt.arms.isNotEmpty &&
          stmt.arms.every((arm) => _alwaysReturns(arm.body));
    }
    return false;
  }

  void _validateClass(ClassDecl cls, Context ctx) {
    final seen = <String, int>{};
    void check(String name, int pos) {
      if (seen.containsKey(name)) {
        ctx.error(pos, "duplicate member '$name' in class '${cls.name}'");
      } else {
        seen[name] = pos;
      }
    }
    for (final f in cls.constructorFields) {
      check(f.name, f.position);
    }
    for (final f in cls.bodyFields) {
      check(f.name, f.position);
    }
    for (final m in cls.methods) {
      check(m.name, m.position);
    }
    for (final fn in cls.methods) {
      _validateFunction(fn, cls.name, ctx);
    }
  }
}
