#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>

typedef struct { uint8_t* ptr; size_t size; } __Slice_uint8_t;

void main_test__print_something(void);
void main_test__add_int(void);
void main_test__sub_int(void);
void io__println(void);
void io__print_str(__Slice_uint8_t s);
void io__print_bool(bool v);
void io__print_u64(uint64_t v);
void io__print_u32(uint32_t v);
void io__print_u16(uint16_t v);
void io__print_u8(uint8_t v);
void io__print_i64(int64_t v);
void io__print_i32(int32_t v);
void io__print_i16(int16_t v);
void io__print_i8(int8_t v);
void io__print_float(float v, uint32_t decimals);
void io__print_fixed(int32_t v, uint32_t decimals);
static void test___test_pass(void);
static void test___test_fail(__Slice_uint8_t file, uint32_t line, __Slice_uint8_t expr);
static void test___test_begin(__Slice_uint8_t name);
static void test___test_end(void);
static int32_t test___report(void);

static uint32_t test___succeeded = 0;
static uint32_t test___failed = 0;
static __Slice_uint8_t test___current_name = (__Slice_uint8_t){(uint8_t*)"", sizeof("") - 1};
static uint32_t test___current_failed = 0;
static uint32_t test___buf_count = 0;
static uint32_t test___buf_lines[8];
static __Slice_uint8_t test___buf_files[8];
static __Slice_uint8_t test___buf_exprs[8];

void main_test__print_something(void) {
  io__print_str((__Slice_uint8_t){(uint8_t*)"Hello, World!", sizeof("Hello, World!") - 1});
  io__println();
  io__print_i32(123);
  io__println();
  io__print_bool(true);
  io__println();
  io__print_float(3.14159f, 2);
  io__println();
  io__print_fixed((-80675), 2);
  io__println();
  const int32_t a = 196608;
  const int32_t b = 131072;
  io__print_fixed(((int32_t)(((int64_t)(a) << 16) / (b))), 2);
  io__println();
}

void io__println(void) {
  putchar(10);
}

void io__print_str(__Slice_uint8_t s) {
  int32_t i = 0;
  while ((i < s.size)) {
    putchar(s.ptr[i]);
    (i += 1);
  }
}

void io__print_bool(bool v) {
  if (v) {
    putchar('t');
    putchar('r');
    putchar('u');
    putchar('e');
  } else {
    putchar('f');
    putchar('a');
    putchar('l');
    putchar('s');
    putchar('e');
  }
}

void io__print_u64(uint64_t v) {
  uint8_t buf[20];
  int32_t i = 19;
  if ((v == 0)) {
    putchar('0');
    return;
  }
  while ((v > 0)) {
    (buf[i] = ((uint8_t)(((v % 10) + 48))));
    (v = (v / 10));
    (i -= 1);
  }
  int32_t j = (i + 1);
  while ((j < 20)) {
    putchar(buf[j]);
    (j += 1);
  }
}

void io__print_u32(uint32_t v) {
  io__print_u64(((uint64_t)(v)));
}

void io__print_u16(uint16_t v) {
  io__print_u64(((uint64_t)(v)));
}

void io__print_u8(uint8_t v) {
  io__print_u64(((uint64_t)(v)));
}

void io__print_i64(int64_t v) {
  if ((v < 0)) {
    putchar('-');
    io__print_u64(((uint64_t)((((int64_t)(0)) - v))));
  } else {
    io__print_u64(((uint64_t)(v)));
  }
}

void io__print_i32(int32_t v) {
  io__print_i64(((int64_t)(v)));
}

void io__print_i16(int16_t v) {
  io__print_i64(((int64_t)(v)));
}

void io__print_i8(int8_t v) {
  io__print_i64(((int64_t)(v)));
}

void io__print_float(float v, uint32_t decimals) {
  float abs = v;
  if ((v < 0)) {
    putchar('-');
    (abs = (0.0f - v));
  }
  const int32_t int_part = ((int32_t)(abs));
  io__print_i32(int_part);
  if ((decimals > 0)) {
    putchar('.');
    float frac = (abs - ((float)(int_part)));
    uint32_t i = 0;
    while ((i < decimals)) {
      (frac = (frac * 10.0f));
      const int32_t digit = ((int32_t)(frac));
      putchar(((uint8_t)((digit + 48))));
      (frac = (frac - ((float)(digit))));
      (i += 1);
    }
  }
}

void io__print_fixed(int32_t v, uint32_t decimals) {
  uint32_t abs = 0;
  if ((v < 0)) {
    putchar('-');
    (abs = ((uint32_t)((0 - v))));
  } else {
    (abs = ((uint32_t)(v)));
  }
  io__print_u32((abs >> 16));
  if ((decimals > 0)) {
    putchar('.');
    uint32_t frac = (abs & 0xFFFF);
    uint32_t i = 0;
    while ((i < decimals)) {
      (frac *= 10);
      putchar(((uint8_t)(((frac >> 16) + 48))));
      (frac = (frac & 0xFFFF));
      (i += 1);
    }
  }
}

static void test___test_pass(void) {
}

static void test___test_fail(__Slice_uint8_t file, uint32_t line, __Slice_uint8_t expr) {
  if ((test___buf_count < 8)) {
    (test___buf_files[test___buf_count] = file);
    (test___buf_lines[test___buf_count] = line);
    (test___buf_exprs[test___buf_count] = expr);
    (test___buf_count += 1);
  }
  (test___current_failed += 1);
}

static void test___test_begin(__Slice_uint8_t name) {
  (test___current_name = name);
  (test___current_failed = 0);
  (test___buf_count = 0);
}

static void test___test_end(void) {
  if ((test___current_failed == 0)) {
    io__print_str((__Slice_uint8_t){(uint8_t*)"\x1b[32mP:", sizeof("\x1b[32mP:") - 1});
    io__print_str(test___current_name);
    io__print_str((__Slice_uint8_t){(uint8_t*)"\x1b[0m", sizeof("\x1b[0m") - 1});
    io__println();
    (test___succeeded += 1);
  } else {
    io__print_str((__Slice_uint8_t){(uint8_t*)"\x1b[31mF:", sizeof("\x1b[31mF:") - 1});
    io__print_str(test___current_name);
    io__print_str((__Slice_uint8_t){(uint8_t*)"\x1b[0m", sizeof("\x1b[0m") - 1});
    io__println();
    uint32_t i = 0;
    while ((i < test___buf_count)) {
      io__print_str((__Slice_uint8_t){(uint8_t*)"  ", sizeof("  ") - 1});
      io__print_str(test___buf_files[i]);
      io__print_str((__Slice_uint8_t){(uint8_t*)":", sizeof(":") - 1});
      io__print_u32(test___buf_lines[i]);
      io__print_str((__Slice_uint8_t){(uint8_t*)": ", sizeof(": ") - 1});
      io__print_str(test___buf_exprs[i]);
      io__println();
      (i += 1);
    }
    (test___failed += 1);
  }
}

static int32_t test___report(void) {
  io__print_str((__Slice_uint8_t){(uint8_t*)"DONE ", sizeof("DONE ") - 1});
  io__print_u32(test___succeeded);
  io__print_str((__Slice_uint8_t){(uint8_t*)"/", sizeof("/") - 1});
  io__print_u32((test___succeeded + test___failed));
  io__println();
  if ((test___failed > 0)) {
    return 1;
  }
  return 0;
}

void main_test__add_int(void) {
  if (!(((1 + 2) == 3))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/src/main_test.mpd", 71}, 27, (__Slice_uint8_t){(uint8_t*)"assert(1 + 2 == 3)", 18});
  } else {
    test___test_pass();
  }
}

void main_test__sub_int(void) {
  if (!(((3 - 1) == 3))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/src/main_test.mpd", 71}, 32, (__Slice_uint8_t){(uint8_t*)"assert(3 - 1 == 3)", 18});
  } else {
    test___test_pass();
  }
}

int main(void) {
    test___test_begin((__Slice_uint8_t){(uint8_t*)"add_int", 7});
    main_test__add_int();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"sub_int", 7});
    main_test__sub_int();
    test___test_end();
    return test___report();
}

