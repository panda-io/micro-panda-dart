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
  void validate(Context context) {}
}
