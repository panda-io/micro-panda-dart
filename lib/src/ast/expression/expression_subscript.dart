import '../../token/token_type.dart';
import '../context.dart';
import '../type/type.dart';
import '../type/type_array.dart';
import '../type/type_builtin.dart';
import 'expression.dart';

class Subscript extends Expression {
  final Expression parent;
  final Expression index;

  Subscript(this.parent, this.index, super.position);

  @override
  void validate(Context context, Type? expected) {
    parent.validate(context, null);
    index.validate(context, TypeBuiltin(TokenType.typeInt32));

    // Check index is integer
    if (index.type != null) {
      if (index.type is! TypeBuiltin ||
          !(index.type as TypeBuiltin).token.isIntegerType) {
        context.error(index.position,
            "array index must be an integer, got ${Context.typeName(index.type)}");
      }
    }

    // Determine element type
    var parentType = parent.type;
    if (parentType is TypeArray) {
      type = parentType.elementType;
      return;
    }

    // Could not determine — leave null
    type = null;
  }
}
