import '../context.dart';
import '../declaration/class_decl.dart';
import '../declaration/function_decl.dart';
import '../type/type.dart';
import '../type/type_array.dart';
import '../type/type_function.dart';
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
    context.calleePosition = true;
    function.validate(context, null);
    context.calleePosition = false;

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
        // Substitute type params so literal arguments adopt the concrete type.
        if (typeArgs.isNotEmpty && fn.typeParams.isNotEmpty) {
          final callSubst = {
            for (var i = 0; i < fn.typeParams.length && i < typeArgs.length; i++)
              fn.typeParams[i]: typeArgs[i]
          };
          paramTypes = paramTypes
              .map((t) => t != null ? _substituteType(t, callSubst) : null)
              .toList();
        }
        _validateArgs(context, paramTypes);
        type = _resolveReturnType(fn, context);
        return;
      }
      // Self method call inside a class body (e.g. _hash(key) inside _find_slot).
      // Self method call inside a class body (e.g. _hash(key) inside _find_slot).
      if (context.currentClass != null) {
        final cls = context.classes[context.currentClass];
        final method = cls?.methods.where((m) => m.name == name).firstOrNull;
        if (method != null) {
          _checkArgCount(context, method.parameters.length, name);
          paramTypes = method.parameters.map((p) => p.type).toList();
          _validateArgs(context, paramTypes);
          type = _resolveReturnType(method, context);
          return;
        }
      }
    }

    if (function is MemberAccess) {
      final ma = function as MemberAccess;
      var receiverType = ma.parent.type;
      if (receiverType is TypeRef) receiverType = receiverType.elementType;

      // Module-qualified function call: string.format_int(a, b)
      // Only apply when the identifier is not a local variable (locals shadow module qualifiers).
      if (ma.parent is Identifier) {
        final qualifier = (ma.parent as Identifier).name;
        if (context.moduleQualifiers.contains(qualifier) && !context.isDeclaredVar(qualifier)) {
          final fn = context.qualifiedFunctions[qualifier]?[ma.member];
          if (fn != null) {
            _checkArgCount(context, fn.parameters.length, '$qualifier.${ma.member}');
            List<Type?> paramTypes = fn.parameters.map((p) => p.type as Type?).toList();
            if (typeArgs.isNotEmpty && fn.typeParams.isNotEmpty) {
              final callSubst = {
                for (var i = 0; i < fn.typeParams.length && i < typeArgs.length; i++)
                  fn.typeParams[i]: typeArgs[i]
              };
              paramTypes = paramTypes
                  .map((t) => t != null ? _substituteType(t, callSubst) : null)
                  .toList();
            }
            _validateArgs(context, paramTypes);
            type = _resolveReturnType(fn, context);
          } else {
            context.error(position,
                "module '$qualifier' has no function '${ma.member}'");
            type = null;
          }
          return;
        }
      }

      // .size() on a slice or fixed array always returns i32.
      if (receiverType is TypeArray && ma.member == 'size') {
        _validateArgs(context, null);
        type = Type.typeI32;
        return;
      }
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
            // Apply method-level type param substitution (e.g. free_array<byte>).
            if (method.typeParams.isNotEmpty) {
              if (typeArgs.isNotEmpty) {
                final methodSubst = {
                  for (var i = 0;
                      i < method.typeParams.length && i < typeArgs.length;
                      i++)
                    method.typeParams[i]: typeArgs[i]
                };
                paramTypes = paramTypes
                    .map((t) => t != null ? _substituteType(t, methodSubst) : null)
                    .toList();
              } else {
                // No explicit type args — skip checking params that reference
                // the method's unresolved type params (they'll be inferred by the generator).
                paramTypes = paramTypes
                    .map((t) => _containsTypeParam(t, method.typeParams) ? null : t)
                    .toList();
              }
            }
            _validateArgs(context, paramTypes);
            type = _resolveReturnType(method, context,
                classTypeSubst: classTypeSubst);
            return;
          }
        }
      }
    }

    // Function pointer call: use TypeFunction signature for param/return types.
    if (function.type is TypeFunction) {
      final tf = function.type as TypeFunction;
      _validateArgs(context, tf.parameters.map((t) => t as Type?).toList());
      type = tf.returnTypes.isEmpty ? null : tf.returnTypes.first;
      return;
    }

    _validateArgs(context, null);
    type = null; // unknown return type
  }

  void _validateArgs(Context context, List<Type?>? paramTypes) {
    for (int i = 0; i < arguments.length; i++) {
      final expectedType = (paramTypes != null && i < paramTypes.length)
          ? paramTypes[i]
          : null;
      arguments[i].validate(context, expectedType);
      if (expectedType != null &&
          !context.typesCompatible(arguments[i].type, expectedType)) {
        context.error(
            arguments[i].position,
            "argument type '${Context.typeName(arguments[i].type)}' is not compatible"
            " with parameter type '${Context.typeName(expectedType)}'");
      }
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
    // Apply function-level type param substitution (e.g. allocate_array<u8>() → u8[])
    if (typeArgs.isNotEmpty && fn.typeParams.isNotEmpty) {
      final callSubst = {
        for (var i = 0; i < fn.typeParams.length && i < typeArgs.length; i++)
          fn.typeParams[i]: typeArgs[i]
      };
      final substituted = _substituteType(retType, callSubst);
      if (substituted != null && substituted != retType) return substituted;
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

  bool _containsTypeParam(Type? type, List<String> typeParams) {
    if (type == null) return false;
    if (type is TypeName && type.typeArgs.isEmpty && typeParams.contains(type.name)) return true;
    if (type is TypeArray) return _containsTypeParam(type.elementType, typeParams);
    if (type is TypeRef) return _containsTypeParam(type.elementType, typeParams);
    return false;
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
