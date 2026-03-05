import '../context.dart';
import '../type/type.dart';
import '../type/type_array.dart';
import 'expression.dart';

/// Array literal initializer: [1, 2, 3]
class ArrayInitializer extends Expression {
  final List<Expression> elements;

  ArrayInitializer(this.elements, super.position);

  @override
  void validate(Context context, Type? expected) {
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
