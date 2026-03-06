import '../ast/context.dart';
import '../ast/module.dart';
import '../ast/declaration/class_decl.dart';
import '../ast/declaration/function_decl.dart';
import '../ast/declaration/variable_decl.dart';
import '../ast/type/type_ref.dart';
import '../ast/type/type_name.dart';

/// Runs semantic validation over all modules.
/// Returns the list of [ValidationError]s found.
/// If the list is empty, the AST is well-typed and safe to generate.
class Validator {
  List<ValidationError> validate(List<Module> modules) {
    final ctx = Context.root(modules);
    for (final mod in modules) {
      final modCtx = ctx.forModule(mod.sourceFile);
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
    for (final fn in cls.methods) {
      _validateFunction(fn, cls.name, ctx);
    }
  }
}
