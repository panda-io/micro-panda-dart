import '../statement/statement_block.dart';
import '../type/type.dart';
import 'declaration.dart';
import 'parameter.dart';

class FunctionDecl extends Declaration {
  final List<Parameter> parameters;
  final Type? returnType;   // null means void
  final Block? body;        // null = declaration only (no body)

  FunctionDecl(super.name, this.parameters, this.returnType, this.body, super.position);
}
