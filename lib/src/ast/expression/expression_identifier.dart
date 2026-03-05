import '../context.dart';
import '../type/type.dart';
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
    // Global function reference
    if (context.globalFunctions.containsKey(name)) {
      type = null; // function reference, type handled at call site
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
}
