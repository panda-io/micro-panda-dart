import 'type.dart';

class TypeFunction extends Type {
  List<Type> returnTypes = [];
  List<Type> parameters = [];

  bool isMemberFunction = false;
  bool isExtern = false;
  String? externName;
  bool isTypeDefine = false;

  TypeFunction([super.position = 0]);

  @override
  bool equal(Type type) {
    if (type is! TypeFunction) return false;

    if (returnTypes.length != type.returnTypes.length) return false;
    for (int i = 0; i < returnTypes.length; i++) {
      if (!returnTypes[i].equal(type.returnTypes[i])) return false;
    }

    if (parameters.length != type.parameters.length) return false;
    for (int i = 0; i < parameters.length; i++) {
      if (!parameters[i].equal(type.parameters[i])) return false;
    }

    return true;
  }
}