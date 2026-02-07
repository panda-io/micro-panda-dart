import 'package:test/test.dart';
import 'package:micro_panda/src/ast/type/type.dart';
import 'package:micro_panda/src/ast/type/type_builtin.dart';
import 'package:micro_panda/src/ast/type/type_array.dart';
import 'package:micro_panda/src/ast/type/type_function.dart';
import 'package:micro_panda/src/ast/type/type_name.dart';
import 'package:micro_panda/src/token/token_type.dart';

void main() {
  group('Type AST Tests', () {
    test('Builtin types properties', () {
      expect(Type.typeBool.isBool, isTrue);
      expect(Type.typeBool.builtinBits, 1);
      expect(Type.typeBool.builtinSize, 1);

      expect(Type.typeU8.isInteger, isTrue);
      expect(Type.typeU8.builtinBits, 8);
      expect(Type.typeU8.builtinSize, 1);
      
      expect(Type.typeF32.isFloat, isTrue);
      expect(Type.typeF32.builtinBits, 32);
      expect(Type.typeF32.builtinSize, 4);
      
      expect(Type.typeI32.isNumber, isTrue);
    });

    test('Builtin equality', () {
      final t1 = TypeBuiltin(TokenType.typeInt32);
      final t2 = TypeBuiltin(TokenType.typeInt32);
      final t3 = TypeBuiltin(TokenType.typeFloat32);

      expect(t1.equal(t2), isTrue);
      expect(t1.equal(t3), isFalse);
    });

    test('Array equality', () {
      // int[10]
      final t1 = TypeArray(Type.typeI32)..dimension.add(10);
      // int[10]
      final t2 = TypeArray(Type.typeI32)..dimension.add(10);
      // int[5]
      final t3 = TypeArray(Type.typeI32)..dimension.add(5);

      expect(t1.equal(t2), isTrue);
      expect(t1.equal(t3), isFalse); 

      // int[2][3]
      final multi1 = TypeArray(Type.typeI32)..dimension.addAll([2, 3]);
      // int[2][3]
      final multi2 = TypeArray(Type.typeI32)..dimension.addAll([2, 3]);
      // int[2][4]
      final multi3 = TypeArray(Type.typeI32)..dimension.addAll([2, 4]);

      expect(multi1.equal(multi2), isTrue);
      // dim[1] is checked, so 3 != 4
      expect(multi1.equal(multi3), isFalse);
    });

    test('Type.elementType getter logic', () {
      final array = TypeArray(Type.typeU8)..dimension.add(5);
      expect(array.elementType.equal(Type.typeU8), isTrue);

      final multiArray = TypeArray(Type.typeU8)..dimension.addAll([5, 5]);
      expect(multiArray.elementType.equal(Type.typeU8), isTrue);
    });

    test('FunctionType equality', () {
      final f1 = TypeFunction();
      f1.returnTypes.add(Type.typeI32);
      f1.parameters.add(Type.typeF32);

      final f2 = TypeFunction();
      f2.returnTypes.add(Type.typeI32);
      f2.parameters.add(Type.typeF32);

      final f3 = TypeFunction();
      f3.returnTypes.add(Type.typeI32);
      f3.parameters.add(Type.typeI32); // Different param

      expect(f1.equal(f2), isTrue);
      expect(f1.equal(f3), isFalse);
      expect(f1.isFunction, isTrue);
    });

    test('TypeName equality and properties', () {
      final n1 = TypeName("MyStruct", qualifiedName: "MyStruct");
      final n2 = TypeName("MyStruct", qualifiedName: "MyStruct");
      final n3 = TypeName("Other", qualifiedName: "Other");

      expect(n1.equal(n2), isTrue);
      expect(n1.equal(n3), isFalse);
      
      expect(n1.isClass, isTrue);
      
      final e1 = TypeName("MyEnum", isEnum: true);
      expect(e1.isClass, isFalse);
    });
  });
}