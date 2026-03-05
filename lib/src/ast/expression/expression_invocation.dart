import '../context.dart';
import '../declaration/function_decl.dart';
import '../type/type.dart';
import '../type/type_name.dart';
import '../type/type_ref.dart';
import 'expression.dart';
import 'expression_identifier.dart';
import 'expression_member_access.dart';

class Invocation extends Expression {
  final Expression function;
  final List<Expression> arguments;
  final List<Type> typeArgs;  // generic type arguments, e.g. [TypeName('Point')]

  Invocation(this.function, this.arguments, super.position, {this.typeArgs = const []});

  @override
  void validate(Context context, Type? expected) {
    function.validate(context, null);

    // Validate each argument
    for (final arg in arguments) {
      arg.validate(context, null);
    }

    // Determine return type from context
    if (function is Identifier) {
      final name = (function as Identifier).name;
      // Constructor call
      if (context.classes.containsKey(name)) {
        type = TypeName(name);
        return;
      }
      // Global function
      final fn = context.globalFunctions[name];
      if (fn != null) {
        _checkArgCount(context, fn.parameters.length, name);
        type = _resolveReturnType(fn, context);
        return;
      }
    }

    if (function is MemberAccess) {
      final ma = function as MemberAccess;
      // Get receiver class
      var receiverType = ma.parent.type;
      if (receiverType is TypeRef) receiverType = receiverType.elementType;
      if (receiverType is TypeName) {
        final cls = context.classes[receiverType.name];
        if (cls != null) {
          final method = cls.methods
              .where((m) => m.name == ma.member)
              .firstOrNull;
          if (method == null) {
            // Could be .size() on array — allowed, skip
          } else {
            _checkArgCount(context, method.parameters.length, ma.member);
            type = _resolveReturnType(method, context);
            return;
          }
        }
      }
    }

    // Generic call: return type is pointer to typeArg
    if (typeArgs.isNotEmpty) {
      type = TypeRef(typeArgs.first);
      return;
    }

    type = null; // unknown return type
  }

  void _checkArgCount(Context context, int expected, String name) {
    if (arguments.length != expected) {
      context.error(position,
          "'$name' expects $expected argument(s), got ${arguments.length}");
    }
  }

  Type? _resolveReturnType(FunctionDecl fn, Context context) {
    final retType = fn.returnType;
    if (typeArgs.isNotEmpty &&
        retType is TypeRef &&
        retType.elementType is TypeName &&
        fn.typeParams.contains((retType.elementType as TypeName).name)) {
      return TypeRef(typeArgs.first);
    }
    return retType;
  }
}
