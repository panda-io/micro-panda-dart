import '../node/node.dart';
import '../context.dart';

abstract class Statement extends Node {
  Statement(super.position);

  void validate(Context context);
}