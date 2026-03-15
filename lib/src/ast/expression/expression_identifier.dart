import '../context.dart';
import '../declaration/function_decl.dart';
import '../type/type.dart';
import '../type/type_function.dart';
import 'expression.dart';

class Identifier extends Expression {
  final String name;

  Identifier(this.name, super.position);

  @override
  void validate(Context context, Type? expected) {
    // Local variable scope
    if (context.isDeclaredVar(name)) {
      type = context.lookupVar(name);
      return;
    }
    // Class field (inside method)
    final fieldType = context.lookupField(name);
    if (fieldType != null) {
      type = fieldType;
      return;
    }
    // Class method reference (bare call inside a method body, e.g. _helper(x))
    if (context.currentClass != null) {
      final cls = context.classes[context.currentClass];
      if (cls != null && cls.methods.any((m) => m.name == name)) {
        type = null; // method reference, type handled at call site
        return;
      }
    }
    // Global function reference
    if (context.globalFunctions.containsKey(name)) {
      final fn = context.globalFunctions[name]!;
      if (fn.isExtern) {
        // @extern functions expand to C templates at call sites — no C address exists.
        if (expected is TypeFunction) {
          context.error(position,
              "'$name' is @extern and cannot be used as a function reference");
        }
        type = null; // type handled at call site only
      } else {
        // Regular and @inline functions both have real C addresses.
        type = _fnType(fn);
      }
      return;
    }
    // Class name (constructor call)
    if (context.classes.containsKey(name)) {
      type = null; // class reference, handled at invocation
      return;
    }
    // Enum name
    if (context.enums.containsKey(name)) {
      type = null;
      return;
    }
    context.error(position, "undefined variable '$name'");
  }

  /// Build a TypeFunction describing [fn]'s signature (for use as a value).
  static TypeFunction _fnType(FunctionDecl fn) {
    final tf = TypeFunction();
    tf.parameters = fn.parameters.map((p) => p.type).toList();
    if (fn.returnType != null) tf.returnTypes = [fn.returnType!];
    return tf;
  }
}
