import 'package:test/test.dart';

import 'package:micro_panda/src/ast/expression/expression_binary.dart';
import 'package:micro_panda/src/ast/expression/expression_identifier.dart';
import 'package:micro_panda/src/ast/expression/expression_literal.dart';
import 'package:micro_panda/src/ast/expression/expression_member_access.dart';
import 'package:micro_panda/src/ast/module.dart';
import 'package:micro_panda/src/ast/statement/statement_block.dart';
import 'package:micro_panda/src/ast/statement/statement_declaration.dart';
import 'package:micro_panda/src/ast/statement/statement_expression.dart';
import 'package:micro_panda/src/ast/statement/statement_for.dart';
import 'package:micro_panda/src/ast/statement/statement_if.dart';
import 'package:micro_panda/src/ast/statement/statement_match.dart';
import 'package:micro_panda/src/ast/statement/statement_return.dart';
import 'package:micro_panda/src/ast/statement/statement_while.dart';
import 'package:micro_panda/src/ast/type/type_array.dart';
import 'package:micro_panda/src/ast/type/type_builtin.dart';
import 'package:micro_panda/src/ast/type/type_name.dart';
import 'package:micro_panda/src/ast/type/type_ref.dart';
import 'package:micro_panda/src/parser/parser.dart';
import 'package:micro_panda/src/token/position.dart' show SourceFile;
import 'package:micro_panda/src/token/token_type.dart';

// Helper: parse source text as a Module.
Module parse(String source) {
  final file = SourceFile('test', 0, source.length);
  return Parser(file, source, {}).parseModule('test');
}

void main() {
  group('Parser – imports', () {
    test('simple import', () {
      final m = parse('import util\n');
      expect(m.imports, hasLength(1));
      expect(m.imports[0].path, 'util');
      expect(m.imports[0].symbol, isNull);
      expect(m.imports[0].alias, isNull);
    });

    test('dotted import', () {
      final m = parse('import util.math\n');
      expect(m.imports[0].path, 'util.math');
    });

    test('import with symbol', () {
      final m = parse('import util.math::min\n');
      expect(m.imports[0].path, 'util.math');
      expect(m.imports[0].symbol, 'min');
    });

    test('import with alias', () {
      final m = parse('import util.math as m\n');
      expect(m.imports[0].alias, 'm');
    });
  });

  group('Parser – variables', () {
    test('var with type and value', () {
      final m = parse('var x: i32 = 42\n');
      expect(m.variables, hasLength(1));
      final v = m.variables[0];
      expect(v.name, 'x');
      expect(v.keyword, TokenType.kVar);
      expect(v.type, isA<TypeBuiltin>());
      expect((v.type as TypeBuiltin).token, TokenType.typeInt32);
      expect(v.value, isA<Literal>());
    });

    test('val with infer-assign', () {
      final m = parse('val x := 10\n');
      final v = m.variables[0];
      expect(v.keyword, TokenType.kVal);
      expect(v.type, isNull);
      expect(v.value, isA<Literal>());
    });

    test('const', () {
      final m = parse('const MAX = 100\n');
      final v = m.variables[0];
      expect(v.keyword, TokenType.kConst);
      expect(v.isConst, isTrue);
    });
  });

  group('Parser – types', () {
    test('reference type', () {
      final m = parse('var p: &Point\n');
      final v = m.variables[0];
      expect(v.type, isA<TypeRef>());
      final inner = (v.type as TypeRef).elementType;
      expect(inner, isA<TypeName>());
      expect((inner as TypeName).name, 'Point');
    });

    test('array type with size', () {
      final m = parse('var buf: u8[32]\n');
      final v = m.variables[0];
      expect(v.type, isA<TypeArray>());
      final arr = v.type as TypeArray;
      expect((arr.elementType as TypeBuiltin).token, TokenType.typeUint8);
      expect(arr.dimension, [32]);
    });

    test('multidimensional array', () {
      final m = parse('var matrix: i32[4][4]\n');
      final arr = m.variables[0].type as TypeArray;
      expect(arr.dimension, [4, 4]);
    });
  });

  group('Parser – functions', () {
    test('function with body', () {
      final src = 'fun add(a: i32, b: i32) i32\n    return a\n';
      final m = parse(src);
      expect(m.functions, hasLength(1));
      final f = m.functions[0];
      expect(f.name, 'add');
      expect(f.parameters, hasLength(2));
      expect(f.returnType, isA<TypeBuiltin>());
      expect(f.body, isA<Block>());
    });

    test('function without body (declaration)', () {
      final src = 'fun tick()\n';
      final m = parse(src);
      final f = m.functions[0];
      expect(f.body, isNull);
    });
  });

  group('Parser – classes', () {
    test('class with constructor fields', () {
      final src = 'class Point(val x: i32, val y: i32)\n';
      final m = parse(src);
      expect(m.classes, hasLength(1));
      final c = m.classes[0];
      expect(c.name, 'Point');
      expect(c.constructorFields, hasLength(2));
      expect(c.constructorFields[0].name, 'x');
    });

    test('class with body fields and methods', () {
      final src = '''class Counter
    var count: i32 = 0
    fun inc() void
''';
      final m = parse(src);
      final c = m.classes[0];
      expect(c.bodyFields, hasLength(1));
      expect(c.methods, hasLength(1));
    });
  });

  group('Parser – enums', () {
    test('plain enum', () {
      final src = 'enum Color\n    Red\n    Green\n    Blue\n';
      final m = parse(src);
      expect(m.enums, hasLength(1));
      final e = m.enums[0];
      expect(e.members, hasLength(3));
      expect(e.members[0].name, 'Red');
      expect(e.members[0].isTagged, isFalse);
      expect(e.members[0].hasValue, isFalse);
    });

    test('value enum', () {
      final src = 'enum OpCode\n    Add = 1\n    Sub = 2\n';
      final m = parse(src);
      final e = m.enums[0];
      expect(e.members[0].hasValue, isTrue);
    });

    test('tagged enum', () {
      final src = 'enum Expr\n    Num(value: i32)\n    Add(left: &Expr, right: &Expr)\n';
      final m = parse(src);
      final e = m.enums[0];
      expect(e.members[0].isTagged, isTrue);
      expect(e.members[0].fields, hasLength(1));
    });
  });

  group('Parser – expressions', () {
    test('binary arithmetic', () {
      final src = 'fun f()\n    var x := 1 + 2\n';
      final m = parse(src);
      final decl = (m.functions[0].body!.statements[0] as DeclarationStatement);
      final bin = decl.value as Binary;
      expect(bin.operator_, TokenType.plus);
    });

    test('precedence: mul before add', () {
      final src = 'fun f()\n    var x := 2 + 3 * 4\n';
      final m = parse(src);
      final decl = m.functions[0].body!.statements[0] as DeclarationStatement;
      final bin = decl.value as Binary;
      // Top node should be +, right should be *
      expect(bin.operator_, TokenType.plus);
      expect((bin.right as Binary).operator_, TokenType.mul);
    });

    test('member access', () {
      final src = 'fun f()\n    var x := a.b\n';
      final m = parse(src);
      final decl = m.functions[0].body!.statements[0] as DeclarationStatement;
      final ma = decl.value as MemberAccess;
      expect(ma.member, 'b');
      expect((ma.parent as Identifier).name, 'a');
    });

    test('right-associative assignment', () {
      final src = 'fun f()\n    a = b = 1\n';
      final m = parse(src);
      final stmt = m.functions[0].body!.statements[0] as ExpressionStatement;
      final outer = stmt.expression as Binary;
      expect(outer.operator_, TokenType.assign);
      expect((outer.right as Binary).operator_, TokenType.assign);
    });
  });

  group('Parser – statements', () {
    test('if statement', () {
      final src = 'fun f()\n    if x > 0\n        return x\n';
      final m = parse(src);
      final ifStmt = m.functions[0].body!.statements[0] as IfStatement;
      expect(ifStmt.condition, isA<Binary>());
      expect(ifStmt.else_, isNull);
    });

    test('if-else', () {
      final src = '''fun f()
    if x > 0
        return x
    else
        return 0
''';
      final m = parse(src);
      final ifStmt = m.functions[0].body!.statements[0] as IfStatement;
      expect(ifStmt.else_, isA<Block>());
    });

    test('while loop', () {
      final src = 'fun f()\n    while i < 10\n        i = i + 1\n';
      final m = parse(src);
      final w = m.functions[0].body!.statements[0] as WhileStatement;
      expect(w.condition, isA<Binary>());
    });

    test('for range loop', () {
      final src = 'fun f()\n    for i in range(0, 10)\n        x = i\n';
      final m = parse(src);
      final f = m.functions[0].body!.statements[0] as ForRangeStatement;
      expect(f.variable, 'i');
    });

    test('for-in loop', () {
      final src = 'fun f()\n    for item in data\n        x = item\n';
      final m = parse(src);
      final f = m.functions[0].body!.statements[0] as ForInStatement;
      expect(f.index, isNull);
      expect(f.item, 'item');
    });

    test('for-in with index', () {
      final src = 'fun f()\n    for i, item in data\n        x = i\n';
      final m = parse(src);
      final f = m.functions[0].body!.statements[0] as ForInStatement;
      expect(f.index, 'i');
      expect(f.item, 'item');
    });

    test('match with wildcard', () {
      final src = '''fun f()
    match x
        1: return x
        _: return 0
''';
      final m = parse(src);
      final ms = m.functions[0].body!.statements[0] as MatchStatement;
      expect(ms.arms, hasLength(2));
      expect(ms.arms[0].pattern, isA<ExpressionPattern>());
      expect(ms.arms[1].pattern, isA<WildcardPattern>());
    });

    test('match with destructure', () {
      final src = '''fun f()
    match expr
        Add(l, r): return l
        _: return 0
''';
      final m = parse(src);
      final ms = m.functions[0].body!.statements[0] as MatchStatement;
      final dp = ms.arms[0].pattern as DestructurePattern;
      expect(dp.variantName, 'Add');
      expect(dp.bindings, ['l', 'r']);
    });

    test('return void', () {
      final src = 'fun f()\n    return\n';
      final m = parse(src);
      final ret = m.functions[0].body!.statements[0] as ReturnStatement;
      expect(ret.value, isNull);
    });
  });
}
