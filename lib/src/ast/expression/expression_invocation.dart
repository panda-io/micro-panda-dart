import '../context.dart';
import '../declaration/class_decl.dart';
import '../declaration/function_decl.dart';
import '../type/type.dart';
import '../type/type_array.dart';
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

    // Determine return type from context and collect parameter types for
    // argument validation (so literals adopt the parameter type, e.g. fixed).
    List<Type?>? paramTypes;

    if (function is Identifier) {
      final name = (function as Identifier).name;
      if (context.classes.containsKey(name)) {
        _validateArgs(context, null);
        type = TypeName(name);
        return;
      }
      final fn = context.globalFunctions[name];
      if (fn != null) {
        _checkArgCount(context, fn.parameters.length, name);
        paramTypes = fn.parameters.map((p) => p.type).toList();
        _validateArgs(context, paramTypes);
        type = _resolveReturnType(fn, context);
        return;
      }
    }

    if (function is MemberAccess) {
      final ma = function as MemberAccess;
      var receiverType = ma.parent.type;
      if (receiverType is TypeRef) receiverType = receiverType.elementType;
      if (receiverType is TypeName) {
        final cls = context.classes[receiverType.name];
        if (cls != null) {
          // Build class type substitution for generic classes (e.g. ArrayList<i32>).
          final classTypeSubst = _buildClassTypeSubst(cls, receiverType.typeArgs);
          final method = cls.methods
              .where((m) => m.name == ma.member)
              .firstOrNull;
          if (method == null) {
            // Could be .size() on array — allowed, skip
          } else {
            _checkArgCount(context, method.parameters.length, ma.member);
            paramTypes = method.parameters
                .map((p) => _substituteType(p.type, classTypeSubst))
                .toList();
            _validateArgs(context, paramTypes);
            type = _resolveReturnType(method, context,
                classTypeSubst: classTypeSubst);
            return;
          }
        }
      }
    }

    _validateArgs(context, null);

    // Generic call: return type is pointer to typeArg
    if (typeArgs.isNotEmpty) {
      type = TypeRef(typeArgs.first);
      return;
    }

    type = null; // unknown return type
  }

  void _validateArgs(Context context, List<Type?>? paramTypes) {
    for (int i = 0; i < arguments.length; i++) {
      final expectedType = (paramTypes != null && i < paramTypes.length)
          ? paramTypes[i]
          : null;
      arguments[i].validate(context, expectedType);
    }
  }

  void _checkArgCount(Context context, int expected, String name) {
    if (arguments.length != expected) {
      context.error(position,
          "'$name' expects $expected argument(s), got ${arguments.length}");
    }
  }

  Type? _resolveReturnType(FunctionDecl fn, Context context,
      {Map<String, Type> classTypeSubst = const {}}) {
    final retType = fn.returnType;
    // Apply class type substitution first (for generic class methods, e.g. get() → T → i32)
    if (classTypeSubst.isNotEmpty) {
      final substituted = _substituteType(retType, classTypeSubst);
      if (substituted != retType) return substituted;
    }
    // Existing logic for function-level type params (e.g. alloc<T>() → &T)
    if (typeArgs.isNotEmpty &&
        retType is TypeRef &&
        retType.elementType is TypeName &&
        fn.typeParams.contains((retType.elementType as TypeName).name)) {
      return TypeRef(typeArgs.first);
    }
    return retType;
  }

  Map<String, Type> _buildClassTypeSubst(ClassDecl cls, List<Type> receiverTypeArgs) {
    if (receiverTypeArgs.isEmpty || cls.typeParams.isEmpty) return {};
    return {
      for (var i = 0; i < cls.typeParams.length && i < receiverTypeArgs.length; i++)
        cls.typeParams[i]: receiverTypeArgs[i]
    };
  }

  Type? _substituteType(Type? type, Map<String, Type> subst) {
    if (subst.isEmpty || type == null) return type;
    if (type is TypeName && type.typeArgs.isEmpty) {
      return subst[type.name] ?? type;
    }
    if (type is TypeRef) {
      final inner = _substituteType(type.elementType, subst);
      if (inner != null && inner != type.elementType) return TypeRef(inner);
    }
    if (type is TypeArray) {
      final elem = _substituteType(type.elementType, subst);
      if (elem != null && elem != type.elementType) {
        final arr = TypeArray(elem, type.position);
        arr.dimension.addAll(type.dimension);
        return arr;
      }
    }
    return type;
  }
}
