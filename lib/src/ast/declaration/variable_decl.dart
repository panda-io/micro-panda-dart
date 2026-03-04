import '../../token/token_type.dart';
import '../expression/expression.dart';
import '../type/type.dart';
import 'declaration.dart';

/// Top-level variable/constant declaration.
/// keyword: kVar, kVal, or kConst.
class VariableDecl extends Declaration {
  final TokenType keyword;
  final Type? type;       // null when using := inference
  final Expression? value;

  VariableDecl(this.keyword, super.name, this.type, this.value, super.position);

  bool get isConst => keyword == TokenType.kConst;
  bool get isMutable => keyword == TokenType.kVar;
}
