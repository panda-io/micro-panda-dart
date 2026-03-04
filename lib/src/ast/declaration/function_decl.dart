import '../annotation.dart';
import '../statement/statement_block.dart';
import '../type/type.dart';
import 'declaration.dart';
import 'parameter.dart';

class FunctionDecl extends Declaration {
  final List<Annotation> annotations;
  final List<Parameter> parameters;
  final Type? returnType;   // null means void
  final Block? body;        // null = declaration only (no body)

  FunctionDecl(super.name, this.parameters, this.returnType, this.body, super.position,
      {this.annotations = const []});

  bool get isExtern => annotations.any((a) => a.name == 'extern');
  Annotation? get externAnnotation =>
      annotations.where((a) => a.name == 'extern').firstOrNull;
}
