import '../node/node.dart';
import '../type/type.dart';
import '../context.dart';

abstract class Expression extends Node {
  bool isConst = false;
  Type? type;

  Expression(super.position);

  void validate(Context context, Type? expected);
}