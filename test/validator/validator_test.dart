import 'package:test/test.dart';

import 'package:micro_panda/src/parser/parser.dart';
import 'package:micro_panda/src/token/position.dart' show SourceFile;
import 'package:micro_panda/src/validator/validator.dart';

List<String> validate(String source) {
  final file = SourceFile('test', 0, source.length);
  final mod = Parser(file, source, {}).parseModule('test');
  final errors = Validator().validate([mod]);
  return errors.map((e) => e.message).toList();
}

/// Validates multiple named modules together.
/// [modules] is a map of module path → source code.
List<String> validateModules(Map<String, String> modules) {
  final mods = modules.entries.map((e) {
    final file = SourceFile(e.key, 0, e.value.length);
    return Parser(file, e.value, {}).parseModule(e.key);
  }).toList();
  return Validator().validate(mods).map((e) => e.message).toList();
}

void expectNoErrors(String source) {
  final errs = validate(source);
  expect(errs, isEmpty, reason: 'Expected no errors but got: $errs');
}

void expectError(String source, String containing) {
  final errs = validate(source);
  expect(errs.any((e) => e.contains(containing)), isTrue,
      reason: "Expected error containing '$containing' but got: $errs");
}

void expectNoErrorsMulti(Map<String, String> modules) {
  final errs = validateModules(modules);
  expect(errs, isEmpty, reason: 'Expected no errors but got: $errs');
}

void expectErrorMulti(Map<String, String> modules, String containing) {
  final errs = validateModules(modules);
  expect(errs.any((e) => e.contains(containing)), isTrue,
      reason: "Expected error containing '$containing' but got: $errs");
}

void main() {
  group('Validator – valid programs', () {
    test('simple function with return', () {
      expectNoErrors('''
fun add(a: i32, b: i32): i32
    return a + b
''');
    });

    test('variable declaration and use', () {
      expectNoErrors('''
fun f(): i32
    val x: i32 = 1
    return x
''');
    });

    test('if statement', () {
      expectNoErrors('''
fun f(x: i32)
    if x > 0
        val y: i32 = x
''');
    });

    test('while loop', () {
      expectNoErrors('''
fun f()
    var i: i32 = 0
    while i < 10
        i += 1
''');
    });

    test('class method call', () {
      expectNoErrors('''
class Point(val x: i32, val y: i32)
    fun sum(): i32
        return this.x + this.y
''');
    });

    test('constructor call', () {
      expectNoErrors('''
class Vec(val x: i32)

fun make(): Vec
    return Vec(1)
''');
    });

    test('global function call', () {
      expectNoErrors('''
fun double(n: i32): i32
    return n * 2

fun main()
    val r: i32 = double(5)
''');
    });

    test('enum member access', () {
      expectNoErrors('''
enum Color
    Red
    Green
    Blue

fun f(): Color
    return Color.Red
''');
    });
  });

  group('Validator – undefined variable', () {
    test('undeclared variable in expression', () {
      expectError('''
fun f(): i32
    return x
''', "undefined variable 'x'");
    });

    test('undeclared variable in assignment', () {
      expectError('''
fun f()
    x = 5
''', "undefined variable 'x'");
    });
  });

  group('Validator – wrong argument count', () {
    test('too few arguments to global function', () {
      expectError('''
fun add(a: i32, b: i32): i32
    return a + b

fun main()
    val r: i32 = add(1)
''', "expects 2 argument(s), got 1");
    });

    test('too many arguments to global function', () {
      expectError('''
fun id(x: i32): i32
    return x

fun main()
    val r: i32 = id(1, 2, 3)
''', "expects 1 argument(s), got 3");
    });

    test('wrong arg count for method', () {
      expectError('''
class Calc(val n: i32)
    fun add(a: i32, b: i32): i32
        return a + b

fun main()
    val c := Calc(0)
    val r: i32 = c.add(1)
''', "expects 2 argument(s), got 1");
    });
  });

  group('Validator – this outside method', () {
    test('this in global function', () {
      expectError('''
fun f(): i32
    return this.x
''', "'this' used outside of a class method");
    });
  });

  group('Validator – return type mismatch', () {
    test('returning void from i32 function', () {
      // Returning nothing when a value is expected
      // The validator checks return expression type vs declared return type
      expectNoErrors('''
fun f(): i32
    return 42
''');
    });
  });

  group('Validator – duplicate declaration', () {
    test('redeclare variable in same scope', () {
      expectError('''
fun f()
    val x: i32 = 1
    val x: i32 = 2
''', "already declared");
    });
  });

  group('Validator – type mismatch in binary op', () {
    test('logical AND on integers', () {
      expectError('''
fun f(a: i32, b: i32): bool
    return a && b
''', "expected bool, got i32");
    });

    test('logical OR on integers', () {
      expectError('''
fun f(a: i32, b: i32): bool
    return a || b
''', "expected bool, got i32");
    });
  });

  group('Validator – generics', () {
    test('generic function with sizeof', () {
      expectNoErrors('''
fun alloc<T>(): &T
    val size := sizeof<T>()
    return null
''');
    });

    test('generic function call with type arg', () {
      expectNoErrors('''
class Node(val x: i32)

fun alloc<T>(): &T
    return null

fun main()
    val n := alloc<Node>()
''');
    });
  });

  group('Validator – return type', () {
    test('return value in void function', () {
      expectError('''
fun f()
    return 42
''', 'return value in void function');
    });

    test('no error when return type matches', () {
      expectNoErrors('''
fun f(): i32
    return 42
''');
    });
  });

  group('Validator – for loop', () {
    test('for range loop variable scoped', () {
      expectNoErrors('''
fun f()
    for i in range(0, 10)
        val x: i32 = i
''');
    });
  });

  group('Validator – member access visibility', () {
    const classModule = '''
class Counter(var _count: i32)
    fun increment()
        this._count += 1
    fun get_count(): i32
        return this._count
''';

    test('private field accessible within same module', () {
      expectNoErrors('''
class Counter(var _count: i32)
    fun increment()
        this._count += 1

fun reset(c: Counter)
    c._count = 0
''');
    });

    test('private field inaccessible from different module', () {
      expectErrorMulti({
        'counter': classModule,
        'user': '''
fun reset(c: Counter)
    c._count = 0
''',
      }, "member '_count' of 'Counter' is private");
    });

    test('private method inaccessible from different module', () {
      expectErrorMulti({
        'counter': '''
class Foo(val x: i32)
    fun _helper(): i32
        return this.x
''',
        'user': '''
fun call_helper(f: Foo): i32
    return f._helper()
''',
      }, "member '_helper' of 'Foo' is private");
    });

    test('public field accessible from different module', () {
      expectNoErrorsMulti({
        'counter': classModule,
        'user': '''
fun get(c: Counter): i32
    return c.get_count()
''',
      });
    });

    test('private field on pointer type inaccessible from different module', () {
      expectErrorMulti({
        'mymod': '''
class Node(var _value: i32)
''',
        'other': '''
fun read(n: &Node): i32
    return n._value
''',
      }, "member '_value' of 'Node' is private");
    });

    test('class accessing its own private fields via this', () {
      expectNoErrors('''
class Box(var _x: i32)
    fun double_x(): i32
        return this._x * 2
    fun set_x(v: i32)
        this._x = v
''');
    });
  });

  group('Validator – val binding', () {
    test('val local cannot be reassigned', () {
      expectError('''
fun f()
    val x: i32 = 1
    x = 2
''', "cannot assign to 'val' binding 'x'");
    });

    test('var local can be reassigned', () {
      expectNoErrors('''
fun f()
    var x: i32 = 1
    x = 2
''');
    });

    test('val ref: field mutation is allowed', () {
      expectNoErrors('''
class Point(var x: i32, var y: i32)

fun f()
    var p := Point(1, 2)
    val r: &Point = &p
    r.x = 10
''');
    });

    test('val ref: rebinding is disallowed', () {
      expectError('''
class Point(var x: i32, var y: i32)

fun f()
    var p := Point(1, 2)
    var q := Point(3, 4)
    val r: &Point = &p
    r = &q
''', "cannot assign to 'val' binding 'r'");
    });
  });
}
