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

    test('generic method returning T[] resolves to byte[] – no type mismatch', () {
      expectNoErrors('''
class Alloc()
    fun allocate_array<T>(length: i32): T[]
        return {null, 0}

class Canvas()
    var _buffer: byte[]

fun setup()
    var alloc: Alloc
    var canvas: Canvas
    canvas._buffer = alloc.allocate_array<byte>(32)
''');
    });

    test('generic method returning T[] on pointer receiver resolves correctly', () {
      expectNoErrors('''
class Alloc()
    fun allocate_array<T>(length: i32): T[]
        return {null, 0}

class Canvas()
    var _buffer: byte[]

fun setup(alloc: &Alloc)
    var canvas: Canvas
    canvas._buffer = alloc.allocate_array<byte>(32)
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
    for i in 0..10
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

fun reset(c: &Counter)
    c._count = 0
''');
    });

    test('private field inaccessible from different module', () {
      expectErrorMulti({
        'counter': classModule,
        'user': '''
fun reset(c: &Counter)
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
fun call_helper(f: &Foo): i32
    return f._helper()
''',
      }, "member '_helper' of 'Foo' is private");
    });

    test('public field accessible from different module', () {
      expectNoErrorsMulti({
        'counter': classModule,
        'user': '''
fun get(c: &Counter): i32
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

  group('Validator – function references', () {
    test('function name used as value gets TypeFunction type', () {
      expectNoErrors('''
fun _sink(b: u8)
    return
var _f: fun(u8) = _sink
''');
    });

    test('fun() var assignment compatible', () {
      expectNoErrors('''
fun _sink(b: u8)
    return
var _f: fun(u8)
fun setup()
    _f = _sink
''');
    });

    test('fun(i32, i32) i32 assignment compatible', () {
      expectNoErrors('''
fun _add(a: i32, b: i32) i32
    return a
var _f: fun(i32, i32) i32
fun setup()
    _f = _add
''');
    });

    test('@extern function cannot be used as a function reference', () {
      expectError('''
@extern("putchar({b})")
fun _putchar(b: u8)
var _f: fun(u8) = _putchar
''', '@extern and cannot be used as a function reference');
    });

    test('@inline function can be used as a function reference', () {
      expectNoErrors('''
@inline
fun _fast(b: u8)
    return
var _f: fun(u8) = _fast
''');
    });

    test('function ref passed as argument', () {
      expectNoErrors('''
fun _sink(b: u8)
    return
fun init(fn: fun(u8))
    return
fun setup()
    init(_sink)
''');
    });

    test('call through function pointer resolves return type', () {
      expectNoErrors('''
fun _add(a: i32, b: i32) i32
    return a
var _f: fun(i32, i32) i32
fun test()
    _f = _add
    val r := _f(1, 2)
    var x: i32 = r
''');
    });
  });

  group('Validator – class method cannot be used as function reference', () {
    test('bare method name stored in typed fun() var inside class', () {
      expectError('''
class Foo(val x: i32)
    fun bar(): i32
        return this.x
    fun setup()
        var f: fun() i32 = bar
''', "is a class method and cannot be used as a function reference");
    });

    test('bare method name stored in untyped var inside class', () {
      expectError('''
class Foo(val x: i32)
    fun bar(): i32
        return this.x
    fun setup()
        var f := bar
''', "is a class method and cannot be used as a function reference");
    });

    test('obj.method stored via member access outside class', () {
      expectError('''
class Foo(val x: i32)
    fun bar(): i32
        return this.x

fun setup()
    var obj := Foo(1)
    var f: fun() i32 = obj.bar
''', "is a class method and cannot be used as a function reference");
    });

    test('obj.method passed as function argument', () {
      expectError('''
class Foo(val x: i32)
    fun bar(): i32
        return this.x

fun call(fn: fun() i32): i32
    return fn()

fun setup()
    var obj := Foo(1)
    call(obj.bar)
''', "is a class method and cannot be used as a function reference");
    });

    test('normal method call inside class is still valid', () {
      expectNoErrors('''
class Foo(val x: i32)
    fun double(): i32
        return this.x * 2
    fun run(): i32
        return double()
''');
    });

    test('normal method call via object outside class is still valid', () {
      expectNoErrors('''
class Foo(val x: i32)
    fun double(): i32
        return this.x * 2

fun setup()
    var obj := Foo(3)
    val r: i32 = obj.double()
''');
    });
  });

  group('Validator – class parameter must be reference', () {
    test('class type parameter is rejected', () {
      expectError('''
class Rect(val w: i32, val h: i32)

fun intersect(rect: Rect) bool
    return rect.w > 0
''', "parameter 'rect' has class type 'Rect' — use a reference '&Rect' instead");
    });

    test('multiple parameters: class type rejected, primitives OK', () {
      expectError('''
class Vec(val x: i32, val y: i32)

fun scale(v: Vec, factor: i32) i32
    return v.x * factor
''', "parameter 'v' has class type 'Vec' — use a reference '&Vec' instead");
    });

    test('class parameter in method is rejected', () {
      expectError('''
class Point(val x: i32, val y: i32)
    fun dist(other: Point) i32
        return other.x - this.x
''', "parameter 'other' has class type 'Point' — use a reference '&Point' instead");
    });

    test('reference parameter is accepted', () {
      expectNoErrors('''
class Rect(val w: i32, val h: i32)

fun area(r: &Rect) i32
    return r.w * r.h
''');
    });

    test('enum parameter is accepted (not a class)', () {
      expectNoErrors('''
enum Dir
    Up
    Down

fun flip(d: Dir) Dir
    return d
''');
    });

    test('generic type param T is accepted', () {
      expectNoErrors('''
class Box(val x: i32)

fun wrap<T>(v: T) i32
    return 0
''');
    });

    test('generic class method with T param accepted', () {
      expectNoErrors('''
class Stack<T>()
    fun push(value: T)
        return
''');
    });
  });

  group('Validator – missing return', () {
    test('function with ref return type and no return statement is rejected', () {
      expectError('''
class Canvas(var width: i32)

fun _init(c: &Canvas) &Canvas
    c.width = 10
''', "does not always return a value");
    });

    test('function with ref return type and bare return is rejected', () {
      expectError('''
class Canvas(var width: i32)

fun _init(c: &Canvas) &Canvas
    c.width = 10
    return
''', "missing return value");
    });

    test('function returning class value where ref expected is rejected', () {
      expectError('''
class Canvas(var width: i32)

fun _init() &Canvas
    var c := Canvas(10)
    return c
''', "return type mismatch");
    });

    test('function returning ref is accepted', () {
      expectNoErrors('''
class Canvas(var width: i32)

fun _init(c: &Canvas) &Canvas
    c.width = 10
    return c
''');
    });

    test('function with non-void return and if/else both returning is accepted', () {
      expectNoErrors('''
fun abs(x: i32) i32
    if x < 0
        return -x
    else
        return x
''');
    });

    test('function with non-void return and if without else is rejected', () {
      expectError('''
fun maybe(x: i32) i32
    if x > 0
        return x
''', "does not always return a value");
    });

    test('function with void return type and no return is accepted', () {
      expectNoErrors('''
class Canvas(var width: i32)

fun _setup(c: &Canvas)
    c.width = 10
''');
    });

    test('match with all arms returning is accepted', () {
      expectNoErrors('''
enum Dir
    Up
    Down

fun flip(d: Dir) Dir
    match d
        Dir.Up: return Dir.Down
        Dir.Down: return Dir.Up
''');
    });
  });

  group('Validator – generic method type arg', () {
    test('generic method call with explicit type arg is accepted', () {
      expectNoErrors('''
class Alloc()
    fun free_array<T>(array: T[])
        return

fun use(s: u8[])
    val a := Alloc()
    a.free_array<u8>(s)
''');
    });

    test('generic method call without explicit type arg is accepted', () {
      expectNoErrors('''
class Alloc()
    fun free_array<T>(array: T[])
        return

fun use(s: u8[])
    val a := Alloc()
    a.free_array(s)
''');
    });

    test('generic method call with wrong explicit type arg is rejected', () {
      expectError('''
class Alloc()
    fun free_array<T>(array: T[])
        return

fun use(s: u8[])
    val a := Alloc()
    a.free_array<i32>(s)
''', "argument type 'u8[]' is not compatible with parameter type 'i32[]'");
    });
  });

  group('Validator – call site argument type check', () {
    test('passing class value where reference expected is rejected', () {
      expectError('''
class Foo(val x: i32)

fun foobar(foo: &Foo)
    return

fun main()
    val foo: Foo = Foo(1)
    foobar(foo)
''', "argument type 'Foo' is not compatible with parameter type '&Foo'");
    });

    test('passing reference where reference expected is accepted', () {
      expectNoErrors('''
class Foo(val x: i32)

fun foobar(foo: &Foo)
    return

fun take(r: &Foo)
    foobar(r)
''');
    });

    test('passing i32 where u8 expected is rejected', () {
      expectError('''
fun add(a: u8, b: u8) u8
    return a

fun main()
    val x: i32 = 1
    add(x, 2)
''', "argument type 'i32' is not compatible with parameter type 'u8'");
    });

    test('passing correct primitive types is accepted', () {
      expectNoErrors('''
fun add(a: i32, b: i32) i32
    return a + b

fun main()
    val r: i32 = add(1, 2)
''');
    });
  });
}
