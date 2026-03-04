import '../node/node.dart';
import '../type/type.dart';

/// A function parameter: name: Type
class Parameter extends Node {
  final String name;
  final Type type;

  Parameter(this.name, this.type, super.position);
}
