import '../context.dart';
import '../declaration/class_decl.dart';
import '../type/type.dart';
import '../type/type_array.dart';
import '../type/type_name.dart';
import '../type/type_ref.dart';
import 'expression.dart';

/// Brace initializer: {expr, expr, ...}
///
/// Serves two purposes determined at validation time:
///   - Slice construction: {ptr, len}  — when expected type is a slice (T[])
///   - Struct initialization: {f1, f2, ...} — when expected type is a class name
class StructInitializer extends Expression {
  final List<Expression> elements;

  StructInitializer(this.elements, super.position);

  @override
  void validate(Context context, Type? expected) {
    // Case 1: expected is a slice type — validate as slice literal {ptr, len}
    if (expected is TypeArray && expected.isSlice) {
      for (final e in elements) {
        e.validate(context, null);
      }
      type = expected;
      return;
    }

    // Case 2: expected is a class name — validate as struct initializer
    if (expected is TypeName) {
      final cls = context.classes[expected.name];
      if (cls != null) {
        final fields = _allFields(cls);
        for (var i = 0; i < elements.length; i++) {
          final fieldType = i < fields.length ? fields[i] : null;
          elements[i].validate(context, fieldType);
        }
        type = expected;
        return;
      }
    }

    // Case 3: no expected type — validate all elements, then infer as slice
    // if the first element is a pointer (TypeRef), matching the existing {ptr, len} idiom
    for (final e in elements) {
      e.validate(context, null);
    }
    if (elements.length == 2) {
      final ptrType = elements[0].type;
      if (ptrType is TypeRef) {
        final sliceType = TypeArray(ptrType.elementType);
        sliceType.dimension.add(0); // dimension[0] == 0 → isSlice
        type = sliceType;
      }
    }
  }

  /// Returns all field types in declaration order (constructor fields, then body fields).
  List<Type?> _allFields(ClassDecl cls) {
    return [
      ...cls.constructorFields.map((f) => f.type),
      ...cls.bodyFields.map((f) => f.type),
    ];
  }
}
