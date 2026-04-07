import '../ast/context.dart';
import '../ast/module.dart';
import '../ast/declaration/class_decl.dart';
import '../ast/declaration/function_decl.dart';
import '../ast/declaration/variable_decl.dart';
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
    for (final v in mod.variables) check(v.name, v.position);
    for (final fn in mod.functions) check(fn.name, fn.position);
    for (final cls in mod.classes) check(cls.name, cls.position);
    for (final enm in mod.enums) check(enm.name, enm.position);
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
    for (final p in fn.parameters) {
      fnCtx.declare(p.name, p.type, p.position);
    }
    fn.body!.validate(fnCtx);
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
    for (final f in cls.constructorFields) check(f.name, f.position);
    for (final f in cls.bodyFields) check(f.name, f.position);
    for (final m in cls.methods) check(m.name, m.position);

    for (final fn in cls.methods) {
      _validateFunction(fn, cls.name, ctx);
    }
  }
}
