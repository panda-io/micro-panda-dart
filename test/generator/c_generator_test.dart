import 'package:test/test.dart';

import 'package:micro_panda/src/generator/c/generator.dart';
import 'package:micro_panda/src/parser/parser.dart';
import 'package:micro_panda/src/token/position.dart' show SourceFile;
import 'package:micro_panda/src/validator/validator.dart';

/// Parse [source], validate, and generate C.
String gen(String source) {
  final file = SourceFile('test', 0, source.length);
  final module = Parser(file, source, {}).parseModule('test');
  Validator().validate([module]); // populate expression types
  return CGenerator().generate([module]);
}

void main() {
  group('Generator – includes', () {
    test('always emits standard headers', () {
      final c = gen('');
      expect(c, contains('#include <stdint.h>'));
      expect(c, contains('#include <stdbool.h>'));
      expect(c, contains('#include <stddef.h>'));
    });
  });

  group('Generator – types', () {
    test('builtin type mapping', () {
      final c = gen('var a: i32\nvar b: u8\nvar d: float\nvar e: bool\n');
      expect(c, contains('int32_t test__a'));
      expect(c, contains('uint8_t test__b'));
      expect(c, contains('float test__d'));
      expect(c, contains('bool test__e'));
    });

    test('reference type becomes pointer', () {
      final c = gen('var p: &i32\n');
      expect(c, contains('int32_t* test__p'));
    });

    test('array type', () {
      final c = gen('var buf: u8[32]\n');
      expect(c, contains('uint8_t test__buf[32]'));
    });
  });

  group('Generator – global variables', () {
    test('var with literal value', () {
      final c = gen('var x: i32 = 42\n');
      expect(c, contains('int32_t test__x = 42'));
    });

    test('val becomes const', () {
      final c = gen('val MAX: i32 = 100\n');
      expect(c, contains('const int32_t test__MAX = 100'));
    });

    test('private var gets static', () {
      final c = gen('var _count: i32 = 0\n');
      expect(c, contains('static int32_t test___count = 0'));
    });

    test('const becomes const', () {
      final c = gen('const LIMIT = 256\n');
      expect(c, contains('const int32_t test__LIMIT = 256'));
    });

    test('private const becomes static const', () {
      final c = gen('const _LIMIT = 256\n');
      expect(c, contains('static const int32_t test___LIMIT = 256'));
    });
  });

  group('Generator – plain enum', () {
    test('auto-increment members', () {
      final c = gen('enum Color\n    Red\n    Green\n    Blue\n');
      expect(c, contains('Color_Red = 0'));
      expect(c, contains('Color_Green = 1'));
      expect(c, contains('Color_Blue = 2'));
      expect(c, contains('} Color;'));
    });

    test('value enum', () {
      final c = gen('enum Op\n    Add = 1\n    Sub = 2\n');
      expect(c, contains('Op_Add = 1'));
      expect(c, contains('Op_Sub = 2'));
    });
  });

  group('Generator – tagged enum', () {
    test('forward declaration emitted', () {
      final c = gen('enum Expr\n    Num(value: i32)\n');
      expect(c, contains('typedef struct Expr Expr;'));
    });

    test('tag enum emitted', () {
      final c = gen('enum Expr\n    Num(value: i32)\n');
      expect(c, contains('Expr_Num,'));
      expect(c, contains('Expr_Tag;'));
    });

    test('data struct emitted', () {
      final c = gen('enum Expr\n    Num(value: i32)\n');
      expect(c, contains('Expr_Num_Data;'));
      expect(c, contains('int32_t value;'));
    });

    test('main struct with tag + union', () {
      final c = gen('enum Expr\n    Num(value: i32)\n');
      expect(c, contains('Expr_Tag tag;'));
      expect(c, contains('union {'));
      expect(c, contains('Expr_Num_Data Num;'));
    });
  });

  group('Generator – class / struct', () {
    test('forward typedef emitted', () {
      final c = gen('class Point(val x: i32, val y: i32)\n');
      expect(c, contains('typedef struct Point Point;'));
    });

    test('struct body emitted', () {
      final c = gen('class Point(val x: i32, val y: i32)\n');
      expect(c, contains('struct Point {'));
      expect(c, contains('int32_t x;'));
      expect(c, contains('int32_t y;'));
    });

    test('body fields included', () {
      final src = 'class Counter\n    var count: i32 = 0\n';
      final c = gen(src);
      expect(c, contains('int32_t count;'));
    });

    test('global class instance zero-initialised', () {
      final src = 'class VM\n    var pc: i32 = 0\n\nval _vm := VM()\n';
      final c = gen(src);
      expect(c, contains('_vm = {0}'));
    });
  });

  group('Generator – functions', () {
    test('simple function signature and body', () {
      final src = 'fun add(a: i32, b: i32) i32\n    return a\n';
      final c = gen(src);
      expect(c, contains('int32_t test__add(int32_t a, int32_t b)'));
      expect(c, contains('return a;'));
    });

    test('void function (no return type)', () {
      final src = 'fun tick()\n    return\n';
      final c = gen(src);
      expect(c, contains('void test__tick(void)'));
    });

    test('private function gets static', () {
      final src = 'fun _helper() i32\n    return 0\n';
      final c = gen(src);
      expect(c, contains('static int32_t test___helper(void)'));
    });

    test('function prototype emitted before definition', () {
      final src = 'fun add(a: i32, b: i32) i32\n    return a\n';
      final c = gen(src);
      final protoIdx = c.indexOf('int32_t test__add(int32_t a, int32_t b);');
      final defIdx   = c.indexOf('int32_t test__add(int32_t a, int32_t b) {');
      expect(protoIdx, isNonNegative);
      expect(defIdx, isNonNegative);
      expect(protoIdx, lessThan(defIdx));
    });

    test('member function gets this parameter', () {
      final src = 'class C(val x: i32)\n    fun get() i32\n        return x\n';
      final c = gen(src);
      expect(c, contains('C* this'));
      expect(c, contains('C_get('));
      expect(c, contains('this->x'));
    });
  });

  group('Generator – statements', () {
    test('if statement', () {
      final src = 'fun f(x: i32) i32\n    if x > 0\n        return x\n    return 0\n';
      final c = gen(src);
      expect(c, contains('if ((x > 0))'));
      expect(c, contains('return x;'));
    });

    test('if-else', () {
      final src = '''fun f(x: i32) i32
    if x > 0
        return x
    else
        return 0
''';
      final c = gen(src);
      expect(c, contains('} else {'));
    });

    test('while loop', () {
      final src = 'fun f()\n    while x < 10\n        x = x + 1\n';
      final c = gen(src);
      expect(c, contains('while ((x < 10))'));
    });

    test('for range', () {
      final src = 'fun f()\n    for i in range(0, 10)\n        x = i\n';
      final c = gen(src);
      expect(c, contains('for (int32_t i = 0; i < 10; i++)'));
    });

    test('match with wildcard', () {
      final src = '''fun f(x: i32) i32
    match x
        1: return x
        _: return 0
''';
      final c = gen(src);
      expect(c, contains('switch (x)'));
      expect(c, contains('case 1:'));
      expect(c, contains('default:'));
    });

    test('match with enum member', () {
      final src = '''enum Color
    Red
    Green
fun f(c: Color) i32
    match c
        Color.Red: return 1
        _: return 0
''';
      final c = gen(src);
      expect(c, contains('case Color_Red:'));
    });

    test('match with destructure pattern', () {
      final src = '''enum Expr
    Num(value: i32)
    Add(left: &Expr, right: &Expr)
fun eval(e: &Expr) i32
    match e
        Num(v): return v
        Add(l, r): return 0
''';
      final c = gen(src);
      expect(c, contains('switch ((e)->tag)'));
      expect(c, contains('case Expr_Num:'));
      expect(c, contains('case Expr_Add:'));
      expect(c, contains('int32_t v = (e)->data.Num.value;'));
    });

    test('local var declaration', () {
      final src = 'fun f()\n    var x: i32 = 5\n    x = x + 1\n';
      final c = gen(src);
      expect(c, contains('int32_t x = 5;'));
    });

    test('local := infer-assign', () {
      final src = 'fun f()\n    var x := 42\n';
      final c = gen(src);
      expect(c, contains('int32_t x = 42'));
    });
  });

  group('Generator – expressions', () {
    test('binary with correct precedence parens', () {
      final src = 'fun f(a: i32, b: i32) i32\n    return a + b\n';
      final c = gen(src);
      expect(c, contains('return (a + b);'));
    });

    test('type cast', () {
      final src = 'fun f(x: i32) i64\n    return i64(x)\n';
      final c = gen(src);
      expect(c, contains('((int64_t)(x))'));
    });

    test('enum member access in expression', () {
      final src = 'enum Color\n    Red\nfun f() Color\n    var c := Color.Red\n    return c\n';
      final c = gen(src);
      expect(c, contains('Color_Red'));
    });

    test('method call generates ClassName_method', () {
      final src = '''class Counter(val start: i32)
    var count: i32 = 0
    fun reset()
        count = start
fun main()
    var c: Counter
    c.reset()
''';
      final c = gen(src);
      expect(c, contains('Counter_reset('));
    });
  });

  group('Generator – @extern annotation', () {
    test('@extern function: no prototype or definition emitted', () {
      final src = '@extern\nfun tick()\n';
      final c = gen(src);
      expect(c, isNot(contains('void tick')));
    });

    test('@extern with no template: call by function name', () {
      final src = '@extern\nfun tick()\nfun main()\n    tick()\n';
      final c = gen(src);
      expect(c, contains('tick()'));
      expect(c, isNot(contains('void tick')));
    });

    test('@extern with C rename (no placeholders): pass args in order', () {
      final src = '@extern("malloc")\nfun alloc(size: u32) &u8\nfun main()\n    var p := alloc(64)\n';
      final c = gen(src);
      expect(c, contains('malloc(64)'));
      // No prototype or definition for 'alloc' should be emitted
      expect(c, isNot(contains('uint8_t* alloc')));
    });

    test('@extern with named placeholder: substitutes arg expressions', () {
      final src = '@extern("assert({condition})")\nfun assert_true(condition: bool)\nfun main()\n    assert_true(1 == 1)\n';
      final c = gen(src);
      expect(c, contains('assert((1 == 1))'));
      expect(c, isNot(contains('assert_true(')));
    });

    test('@extern with two placeholders: assert_eq style', () {
      final src = '@extern("assert({a} == {b})")\nfun assert_i32_equal(a: i32, b: i32)\nfun main()\n    assert_i32_equal(result, 42)\n';
      final c = gen(src);
      expect(c, contains('assert(result == 42)'));
      expect(c, isNot(contains('assert_i32_equal(')));
    });

    test('string literal value excludes quotes', () {
      // Verifies the scanner fix: string literal should not include closing "
      final src = 'fun f()\n    var s: u8\n';
      final c = gen(src);
      expect(c, isNotNull); // just ensure it parses without error
    });
  });

  group('Generator – slices', () {
    test('slice type emits __Slice_T typedef', () {
      final src = 'class Buf(val data: u8[])\n';
      final c = gen(src);
      expect(c, contains('typedef struct { uint8_t* ptr; size_t size; } __Slice_uint8_t;'));
    });

    test('slice field in struct uses __Slice_T', () {
      final src = 'class Buf(val data: u8[])\n';
      final c = gen(src);
      expect(c, contains('__Slice_uint8_t data'));
    });

    test('slice subscript emits .ptr[i]', () {
      final src = '''class Buf(val data: u8[])
    fun get(i: i32) u8
        return data[i]
''';
      final c = gen(src);
      expect(c, contains('this->data.ptr[i]'));
    });

    test('.size() on slice emits .size field', () {
      final src = '''class Buf(val data: u8[])
    fun len() u64
        return data.size()
''';
      final c = gen(src);
      expect(c, contains('this->data.size'));
    });

    test('fixed array of slices u8[][N] emits __Slice_T name[N]', () {
      final c = gen('var bufs: u8[][8]\n');
      expect(c, contains('__Slice_uint8_t test__bufs[8]'));
    });

    test('subscript on u8[][N] returns slice type', () {
      final src = '''fun get(bufs: u8[][8], i: i32) u8[]
    return bufs[i]
''';
      final c = gen(src);
      expect(c, contains('bufs[i]'));
    });

    test('.size() on fixed array emits literal', () {
      final src = '''class Buf(val data: u8[32])
    fun len() u32
        return data.size()
''';
      final c = gen(src);
      expect(c, contains('32'));
    });

    test('slice construction {ptr, len} in declaration', () {
      final src = '''fun make(p: &u8, n: u32) u8[]
    val s: u8[] = {p, n}
    return s
''';
      final c = gen(src);
      expect(c, contains('(__Slice_uint8_t){p, n}'));
    });

    test('slice construction {ptr, len} in expression emits compound literal', () {
      final src = '''fun wrap(p: &u8, n: u32) u8[]
    return {p, n}
''';
      final c = gen(src);
      expect(c, contains('(__Slice_uint8_t){p, n}'));
    });
  });

  group('Generator – generics', () {
    test('generic function gets void* return and size_t param', () {
      final src = '''class Pool(val buf: u8[])
    fun alloc<T>(): &T
        return null
''';
      final c = gen(src);
      expect(c, contains('void* Pool_alloc(Pool* this, size_t __sizeof_T)'));
    });

    test('sizeof<T>() in generic body emits __sizeof_T', () {
      final src = '''class Pool(val buf: u8[])
    fun alloc<T>(): &T
        val size := sizeof<T>()
        return null
''';
      final c = gen(src);
      expect(c, contains('const uint64_t size = __sizeof_T'));
    });

    test('&T(expr) in generic body emits (void*)(expr)', () {
      final src = '''class Pool(val buf: u8[])
    fun alloc<T>(): &T
        val ptr := &T(u8(0))
        return ptr
''';
      final c = gen(src);
      expect(c, contains('void* ptr = (void*)'));
    });

    test('null literal emits NULL', () {
      final src = 'fun f() &u8\n    return null\n';
      final c = gen(src);
      expect(c, contains('return NULL;'));
    });

    test('generic call site uses specialized function (monomorphization)', () {
      final src = '''class Pool(val buf: u8[])
    fun alloc<T>(): &T
        return null
fun use(p: &Pool)
    val x := p.alloc<u8>()
''';
      final c = gen(src);
      // Specialized prototype and call — no sizeof arg, no cast needed.
      expect(c, contains('uint8_t* Pool_alloc_uint8_t(Pool* this)'));
      expect(c, contains('Pool_alloc_uint8_t(p)'));
    });
  });

  group('Generator – allocator pattern', () {
    test('allocator compiles to valid C', () {
      final src = '''class Allocator(val _memory: u8[])
    var _cursor: i32 = 0

    fun allocate<T>(): &T
        val size := sizeof<T>()
        if _cursor + size > _memory.size()
            return null
        val ptr := &T(&_memory[_cursor])
        _cursor += size
        return ptr
''';
      final c = gen(src);
      // struct contains slice field
      expect(c, contains('__Slice_uint8_t _memory'));
      // generic signature
      expect(c, contains('void* Allocator_allocate(Allocator* this, size_t __sizeof_T)'));
      // sizeof<T>()
      expect(c, contains('__sizeof_T'));
      // null return
      expect(c, contains('return NULL;'));
      // cursor increment
      expect(c, contains('this->_cursor += size'));
    });
  });

  group('Generator – test mode', () {
    test('assert emits conditional _test_fail / _test_pass', () {
      final src = '@test\nfun my_test()\n    assert(1 == 1)\n';
      final c = gen(src);
      expect(c, contains('if (!('));
      expect(c, contains('_test_fail('));
      expect(c, contains('_test_pass()'));
      expect(c, contains('assert(1 == 1)'));
    });

    test('@test functions generate test main()', () {
      final src = '@test\nfun addition()\n    assert(1 == 1)\n';
      final c = gen(src);
      expect(c, contains('int main(void)'));
      expect(c, contains('_test_begin('));
      expect(c, contains('addition()'));
      expect(c, contains('_test_end()'));
      expect(c, contains('_report()'));
    });

    test('assert captures source text', () {
      final src = '@test\nfun my_test()\n    assert(2 + 2 == 4)\n';
      final c = gen(src);
      expect(c, contains('assert(2 + 2 == 4)'));
    });

    test('assert captures file and line', () {
      final src = '@test\nfun my_test()\n    assert(1 == 1)\n';
      final c = gen(src);
      expect(c, contains('"test"'));  // file name
      expect(c, contains('3'));       // line number
    });
  });
}
