import '../../token/token_type.dart';
import '../context.dart';
import '../expression/expression.dart';
import '../type/type.dart';
import 'statement.dart';

/// Local variable declaration inside a function body.
/// keyword is kVar, kVal, or kConst.
class DeclarationStatement extends Statement {
  final TokenType keyword;
  final String name;
  final Type? type;       // null when using := inference
  final Expression? value;

  DeclarationStatement(this.keyword, this.name, this.type, this.value, super.position);

  @override
  void validate(Context context) {
    Type? resolvedType = type;
    if (value != null) {
      value!.validate(context, type);
      // Infer type from initializer if not explicit
      resolvedType ??= value!.type;
      // Check compatibility if both are known
      if (type != null && !context.typesCompatible(type, value!.type)) {
        context.error(position,
            "cannot assign ${Context.typeName(value!.type)} "
            "to ${Context.typeName(type)}");
      }
    }
    context.declare(name, resolvedType, position);
  }
}
