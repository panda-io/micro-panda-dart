import '../context.dart';
import '../type/type.dart';
import '../type/type_array.dart';
import 'expression.dart';

/// Array literal initializer: [1, 2, 3]
/// Also used for slice construction: {ptr, len} (isSliceLiteral = true)
class ArrayInitializer extends Expression {
  final List<Expression> elements;
  final bool isSliceLiteral;

  ArrayInitializer(this.elements, super.position, {this.isSliceLiteral = false});

  @override
  void validate(Context context, Type? expected) {
    // Slice construction: {ptr, len} when expected type is a slice
    if (expected is TypeArray && expected.isSlice && elements.length == 2) {
      elements[0].validate(context, null);
      elements[1].validate(context, null);
      type = expected;
      return;
    }

    // Determine element type from expected or first element
    Type? elemType;
    if (expected is TypeArray) elemType = expected.elementType;

    for (final e in elements) {
      e.validate(context, elemType);
      elemType ??= e.type;
    }

    if (elemType != null) {
      final arr = TypeArray(elemType);
      arr.dimension.add(elements.length);
      type = arr;
    }
  }
}
