import 'package:micro_panda/src/token/token_type.dart';
import 'type.dart';

class TypeBuiltin extends Type {
  final TokenType token;
  TypeBuiltin(this.token, [super.position = 0]);

  @override
  bool equal(Type type) => type is TypeBuiltin && type.token == token;
}