#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>

typedef struct { uint8_t* ptr; size_t size; } __Slice_uint8_t;
typedef struct { int32_t* ptr; size_t size; } __Slice_int32_t;
typedef struct { uint32_t* ptr; size_t size; } __Slice_uint32_t;

typedef struct ArrayList_int32_t ArrayList_int32_t;
typedef struct LinkedList_int32_t LinkedList_int32_t;
typedef struct RingBuffer_int32_t RingBuffer_int32_t;
typedef struct Allocator Allocator;

struct ArrayList_int32_t {
  __Slice_int32_t _buffer;
  uint32_t _size;
};

struct LinkedList_int32_t {
  __Slice_uint32_t _next;
  __Slice_uint32_t _prev;
  __Slice_int32_t _data;
  uint32_t _head;
  uint32_t _tail;
  uint32_t _free;
  uint32_t _size;
  uint32_t _cap;
};

struct RingBuffer_int32_t {
  __Slice_int32_t _buffer;
  uint32_t _head;
  uint32_t _tail;
  uint32_t _size;
};

struct Allocator {
  uint8_t* _ptr;
  uint32_t _capacity;
  uint32_t _cursor;
};

void collection_test__arraylist_init(void);
void collection_test__arraylist_push_pop(void);
void collection_test__arraylist_full(void);
void collection_test__arraylist_set_clear(void);
void collection_test__linkedlist_init(void);
void collection_test__linkedlist_push_back_pop_front(void);
void collection_test__linkedlist_push_front_pop_back(void);
void collection_test__linkedlist_full_reuse(void);
void collection_test__ringbuffer_init(void);
void collection_test__ringbuffer_push_pop(void);
void collection_test__ringbuffer_wrap_around(void);
static void test___test_pass(void);
static void test___test_fail(__Slice_uint8_t file, uint32_t line, __Slice_uint8_t expr);
static void test___test_begin(__Slice_uint8_t name);
static void test___test_end(void);
static int32_t test___report(void);
bool ArrayList_int32_t_init(ArrayList_int32_t* this, Allocator* allocator, uint32_t capacity);
bool ArrayList_int32_t_push(ArrayList_int32_t* this, int32_t value);
bool ArrayList_int32_t_pop(ArrayList_int32_t* this);
int32_t ArrayList_int32_t_get(ArrayList_int32_t* this, uint32_t i);
void ArrayList_int32_t_set(ArrayList_int32_t* this, uint32_t i, int32_t value);
int32_t ArrayList_int32_t_top(ArrayList_int32_t* this);
uint32_t ArrayList_int32_t_size(ArrayList_int32_t* this);
uint32_t ArrayList_int32_t_capacity(ArrayList_int32_t* this);
bool ArrayList_int32_t_is_empty(ArrayList_int32_t* this);
bool ArrayList_int32_t_is_full(ArrayList_int32_t* this);
void ArrayList_int32_t_clear(ArrayList_int32_t* this);
bool LinkedList_int32_t_init(LinkedList_int32_t* this, Allocator* allocator, uint32_t capacity);
bool LinkedList_int32_t_push_back(LinkedList_int32_t* this, int32_t value);
bool LinkedList_int32_t_push_front(LinkedList_int32_t* this, int32_t value);
bool LinkedList_int32_t_pop_front(LinkedList_int32_t* this);
bool LinkedList_int32_t_pop_back(LinkedList_int32_t* this);
int32_t LinkedList_int32_t_front(LinkedList_int32_t* this);
int32_t LinkedList_int32_t_back(LinkedList_int32_t* this);
uint32_t LinkedList_int32_t_size(LinkedList_int32_t* this);
uint32_t LinkedList_int32_t_capacity(LinkedList_int32_t* this);
bool LinkedList_int32_t_is_empty(LinkedList_int32_t* this);
bool LinkedList_int32_t_is_full(LinkedList_int32_t* this);
bool RingBuffer_int32_t_init(RingBuffer_int32_t* this, Allocator* allocator, uint32_t capacity);
bool RingBuffer_int32_t_push(RingBuffer_int32_t* this, int32_t value);
bool RingBuffer_int32_t_pop(RingBuffer_int32_t* this);
int32_t RingBuffer_int32_t_peek(RingBuffer_int32_t* this);
uint32_t RingBuffer_int32_t_size(RingBuffer_int32_t* this);
uint32_t RingBuffer_int32_t_capacity(RingBuffer_int32_t* this);
bool RingBuffer_int32_t_is_empty(RingBuffer_int32_t* this);
bool RingBuffer_int32_t_is_full(RingBuffer_int32_t* this);
void Allocator_init(Allocator* this, uint32_t capacity);
void* Allocator_allocate(Allocator* this, size_t __sizeof_T);
void Allocator_reset(Allocator* this);
static bool Allocator__check_buffer(Allocator* this, uint32_t size);
void console__println(void);
void console__print_str(__Slice_uint8_t s);
void console__print_bool(bool v);
void console__print_u64(uint64_t v);
void console__print_u32(uint32_t v);
void console__print_u16(uint16_t v);
void console__print_u8(uint8_t v);
void console__print_i64(int64_t v);
void console__print_i32(int32_t v);
void console__print_i16(int16_t v);
void console__print_i8(int8_t v);
void console__print_float(float v, uint32_t decimals);
void console__print_fixed(int32_t v, uint32_t decimals);
__Slice_int32_t Allocator_allocate_array_int32_t(Allocator* this, uint32_t length);
__Slice_uint32_t Allocator_allocate_array_uint32_t(Allocator* this, uint32_t length);

static uint32_t test___succeeded = 0;
static uint32_t test___failed = 0;
static __Slice_uint8_t test___current_name = (__Slice_uint8_t){(uint8_t*)"", sizeof("") - 1};
static uint32_t test___current_failed = 0;
static uint32_t test___buf_count = 0;
static uint32_t test___buf_lines[8];
static __Slice_uint8_t test___buf_files[8];
static __Slice_uint8_t test___buf_exprs[8];

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
    console__print_str((__Slice_uint8_t){(uint8_t*)"\x1b[32mP:", sizeof("\x1b[32mP:") - 1});
    console__print_str(test___current_name);
    console__print_str((__Slice_uint8_t){(uint8_t*)"\x1b[0m", sizeof("\x1b[0m") - 1});
    console__println();
    (test___succeeded += 1);
  } else {
    console__print_str((__Slice_uint8_t){(uint8_t*)"\x1b[31mF:", sizeof("\x1b[31mF:") - 1});
    console__print_str(test___current_name);
    console__print_str((__Slice_uint8_t){(uint8_t*)"\x1b[0m", sizeof("\x1b[0m") - 1});
    console__println();
    uint32_t i = 0;
    while ((i < test___buf_count)) {
      console__print_str((__Slice_uint8_t){(uint8_t*)"  ", sizeof("  ") - 1});
      console__print_str(test___buf_files[i]);
      console__print_str((__Slice_uint8_t){(uint8_t*)":", sizeof(":") - 1});
      console__print_u32(test___buf_lines[i]);
      console__print_str((__Slice_uint8_t){(uint8_t*)": ", sizeof(": ") - 1});
      console__print_str(test___buf_exprs[i]);
      console__println();
      (i += 1);
    }
    (test___failed += 1);
  }
}

static int32_t test___report(void) {
  console__print_str((__Slice_uint8_t){(uint8_t*)"DONE ", sizeof("DONE ") - 1});
  console__print_u32(test___succeeded);
  console__print_str((__Slice_uint8_t){(uint8_t*)"/", sizeof("/") - 1});
  console__print_u32((test___succeeded + test___failed));
  console__println();
  if ((test___failed > 0)) {
    return 1;
  }
  return 0;
}

bool ArrayList_int32_t_init(ArrayList_int32_t* this, Allocator* allocator, uint32_t capacity) {
  (this->_buffer = Allocator_allocate_array_int32_t(allocator, capacity));
  if ((this->_buffer.size == 0)) {
    return false;
  }
  return true;
}

bool ArrayList_int32_t_push(ArrayList_int32_t* this, int32_t value) {
  if ((this->_size >= this->_buffer.size)) {
    return false;
  }
  (this->_buffer.ptr[this->_size] = value);
  (this->_size += 1);
  return true;
}

bool ArrayList_int32_t_pop(ArrayList_int32_t* this) {
  if ((this->_size == 0)) {
    return false;
  }
  (this->_size -= 1);
  return true;
}

int32_t ArrayList_int32_t_get(ArrayList_int32_t* this, uint32_t i) {
  return this->_buffer.ptr[i];
}

void ArrayList_int32_t_set(ArrayList_int32_t* this, uint32_t i, int32_t value) {
  (this->_buffer.ptr[i] = value);
}

int32_t ArrayList_int32_t_top(ArrayList_int32_t* this) {
  return this->_buffer.ptr[(this->_size - 1)];
}

uint32_t ArrayList_int32_t_size(ArrayList_int32_t* this) {
  return this->_size;
}

uint32_t ArrayList_int32_t_capacity(ArrayList_int32_t* this) {
  return this->_buffer.size;
}

bool ArrayList_int32_t_is_empty(ArrayList_int32_t* this) {
  return (this->_size == 0);
}

bool ArrayList_int32_t_is_full(ArrayList_int32_t* this) {
  return (this->_size >= this->_buffer.size);
}

void ArrayList_int32_t_clear(ArrayList_int32_t* this) {
  (this->_size = 0);
}

bool LinkedList_int32_t_init(LinkedList_int32_t* this, Allocator* allocator, uint32_t capacity) {
  (this->_next = Allocator_allocate_array_uint32_t(allocator, capacity));
  if ((this->_next.size == 0)) {
    return false;
  }
  (this->_prev = Allocator_allocate_array_uint32_t(allocator, capacity));
  if ((this->_prev.size == 0)) {
    return false;
  }
  (this->_data = Allocator_allocate_array_int32_t(allocator, capacity));
  if ((this->_data.size == 0)) {
    return false;
  }
  (this->_cap = capacity);
  (this->_head = this->_cap);
  (this->_tail = this->_cap);
  uint32_t i = 0;
  while ((i < (capacity - 1))) {
    (this->_next.ptr[i] = (i + 1));
    (i += 1);
  }
  (this->_next.ptr[(capacity - 1)] = this->_cap);
  (this->_free = 0);
  return true;
}

bool LinkedList_int32_t_push_back(LinkedList_int32_t* this, int32_t value) {
  if ((this->_free == this->_cap)) {
    return false;
  }
  const uint32_t node = this->_free;
  (this->_free = this->_next.ptr[node]);
  (this->_data.ptr[node] = value);
  (this->_next.ptr[node] = this->_cap);
  (this->_prev.ptr[node] = this->_tail);
  if ((this->_tail != this->_cap)) {
    (this->_next.ptr[this->_tail] = node);
  } else {
    (this->_head = node);
  }
  (this->_tail = node);
  (this->_size += 1);
  return true;
}

bool LinkedList_int32_t_push_front(LinkedList_int32_t* this, int32_t value) {
  if ((this->_free == this->_cap)) {
    return false;
  }
  const uint32_t node = this->_free;
  (this->_free = this->_next.ptr[node]);
  (this->_data.ptr[node] = value);
  (this->_prev.ptr[node] = this->_cap);
  (this->_next.ptr[node] = this->_head);
  if ((this->_head != this->_cap)) {
    (this->_prev.ptr[this->_head] = node);
  } else {
    (this->_tail = node);
  }
  (this->_head = node);
  (this->_size += 1);
  return true;
}

bool LinkedList_int32_t_pop_front(LinkedList_int32_t* this) {
  if ((this->_head == this->_cap)) {
    return false;
  }
  const uint32_t node = this->_head;
  (this->_head = this->_next.ptr[node]);
  if ((this->_head != this->_cap)) {
    (this->_prev.ptr[this->_head] = this->_cap);
  } else {
    (this->_tail = this->_cap);
  }
  (this->_next.ptr[node] = this->_free);
  (this->_free = node);
  (this->_size -= 1);
  return true;
}

bool LinkedList_int32_t_pop_back(LinkedList_int32_t* this) {
  if ((this->_tail == this->_cap)) {
    return false;
  }
  const uint32_t node = this->_tail;
  (this->_tail = this->_prev.ptr[node]);
  if ((this->_tail != this->_cap)) {
    (this->_next.ptr[this->_tail] = this->_cap);
  } else {
    (this->_head = this->_cap);
  }
  (this->_next.ptr[node] = this->_free);
  (this->_free = node);
  (this->_size -= 1);
  return true;
}

int32_t LinkedList_int32_t_front(LinkedList_int32_t* this) {
  return this->_data.ptr[this->_head];
}

int32_t LinkedList_int32_t_back(LinkedList_int32_t* this) {
  return this->_data.ptr[this->_tail];
}

uint32_t LinkedList_int32_t_size(LinkedList_int32_t* this) {
  return this->_size;
}

uint32_t LinkedList_int32_t_capacity(LinkedList_int32_t* this) {
  return this->_cap;
}

bool LinkedList_int32_t_is_empty(LinkedList_int32_t* this) {
  return (this->_head == this->_cap);
}

bool LinkedList_int32_t_is_full(LinkedList_int32_t* this) {
  return (this->_free == this->_cap);
}

bool RingBuffer_int32_t_init(RingBuffer_int32_t* this, Allocator* allocator, uint32_t capacity) {
  (this->_buffer = Allocator_allocate_array_int32_t(allocator, capacity));
  if ((this->_buffer.size == 0)) {
    return false;
  }
  return true;
}

bool RingBuffer_int32_t_push(RingBuffer_int32_t* this, int32_t value) {
  if ((this->_size >= this->_buffer.size)) {
    return false;
  }
  (this->_buffer.ptr[this->_tail] = value);
  (this->_tail = ((this->_tail + 1) % this->_buffer.size));
  (this->_size += 1);
  return true;
}

bool RingBuffer_int32_t_pop(RingBuffer_int32_t* this) {
  if ((this->_size == 0)) {
    return false;
  }
  (this->_head = ((this->_head + 1) % this->_buffer.size));
  (this->_size -= 1);
  return true;
}

int32_t RingBuffer_int32_t_peek(RingBuffer_int32_t* this) {
  return this->_buffer.ptr[this->_head];
}

uint32_t RingBuffer_int32_t_size(RingBuffer_int32_t* this) {
  return this->_size;
}

uint32_t RingBuffer_int32_t_capacity(RingBuffer_int32_t* this) {
  return this->_buffer.size;
}

bool RingBuffer_int32_t_is_empty(RingBuffer_int32_t* this) {
  return (this->_size == 0);
}

bool RingBuffer_int32_t_is_full(RingBuffer_int32_t* this) {
  return (this->_size >= this->_buffer.size);
}

void Allocator_init(Allocator* this, uint32_t capacity) {
  (this->_ptr = malloc(capacity));
  (this->_capacity = capacity);
}

void* Allocator_allocate(Allocator* this, size_t __sizeof_T) {
  const uint64_t size = __sizeof_T;
  if (Allocator__check_buffer(this, size)) {
    const void* ptr = (void*)((&this->_ptr[this->_cursor]));
    (this->_cursor += size);
    return ptr;
  }
  return NULL;
}

void Allocator_reset(Allocator* this) {
  (this->_cursor = 0);
}

static bool Allocator__check_buffer(Allocator* this, uint32_t size) {
  if (((this->_cursor + size) > this->_capacity)) {
    (this->_capacity = (this->_capacity * 2));
    (this->_ptr = realloc(this->_ptr, this->_capacity));
    if ((this->_ptr == NULL)) {
      return false;
    }
  }
  return true;
}

void console__println(void) {
  putchar(10);
}

void console__print_str(__Slice_uint8_t s) {
  int32_t i = 0;
  while ((i < s.size)) {
    putchar(s.ptr[i]);
    (i += 1);
  }
}

void console__print_bool(bool v) {
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

void console__print_u64(uint64_t v) {
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

void console__print_u32(uint32_t v) {
  console__print_u64(((uint64_t)(v)));
}

void console__print_u16(uint16_t v) {
  console__print_u64(((uint64_t)(v)));
}

void console__print_u8(uint8_t v) {
  console__print_u64(((uint64_t)(v)));
}

void console__print_i64(int64_t v) {
  if ((v < 0)) {
    putchar('-');
    console__print_u64(((uint64_t)((((int64_t)(0)) - v))));
  } else {
    console__print_u64(((uint64_t)(v)));
  }
}

void console__print_i32(int32_t v) {
  console__print_i64(((int64_t)(v)));
}

void console__print_i16(int16_t v) {
  console__print_i64(((int64_t)(v)));
}

void console__print_i8(int8_t v) {
  console__print_i64(((int64_t)(v)));
}

void console__print_float(float v, uint32_t decimals) {
  float abs = v;
  if ((v < 0.0f)) {
    putchar('-');
    (abs = (0.0f - v));
  }
  const int32_t int_part = ((int32_t)(abs));
  console__print_i32(int_part);
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

void console__print_fixed(int32_t v, uint32_t decimals) {
  uint32_t abs = 0;
  if ((v < 0)) {
    putchar('-');
    (abs = ((uint32_t)((0 - v))));
  } else {
    (abs = ((uint32_t)(v)));
  }
  console__print_u32((abs >> 16));
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

__Slice_int32_t Allocator_allocate_array_int32_t(Allocator* this, uint32_t length) {
  const uint64_t size = (sizeof(int32_t) * length);
  if (Allocator__check_buffer(this, size)) {
    const int32_t* ptr = ((int32_t*)((&this->_ptr[this->_cursor])));
    (this->_cursor += size);
    return (__Slice_int32_t){ptr, length};
  }
  return (__Slice_int32_t){0};
}

__Slice_uint32_t Allocator_allocate_array_uint32_t(Allocator* this, uint32_t length) {
  const uint64_t size = (sizeof(uint32_t) * length);
  if (Allocator__check_buffer(this, size)) {
    const uint32_t* ptr = ((uint32_t*)((&this->_ptr[this->_cursor])));
    (this->_cursor += size);
    return (__Slice_uint32_t){ptr, length};
  }
  return (__Slice_uint32_t){0};
}

void collection_test__arraylist_init(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  ArrayList_int32_t list = {0};
  if (!(ArrayList_int32_t_init((&list), (&alloc), 4))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 14, (__Slice_uint8_t){(uint8_t*)"assert(list.init(&alloc, 4))", 28});
  } else {
    test___test_pass();
  }
  if (!(ArrayList_int32_t_is_empty((&list)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 15, (__Slice_uint8_t){(uint8_t*)"assert(list.is_empty())", 23});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_size((&list)) == 0))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 16, (__Slice_uint8_t){(uint8_t*)"assert(list.size() == 0)", 24});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_capacity((&list)) == 4))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 17, (__Slice_uint8_t){(uint8_t*)"assert(list.capacity() == 4)", 28});
  } else {
    test___test_pass();
  }
}

void collection_test__arraylist_push_pop(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  ArrayList_int32_t list = {0};
  ArrayList_int32_t_init((&list), (&alloc), 4);
  if (!(ArrayList_int32_t_push((&list), 10))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 25, (__Slice_uint8_t){(uint8_t*)"assert(list.push(10))", 21});
  } else {
    test___test_pass();
  }
  if (!(ArrayList_int32_t_push((&list), 20))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 26, (__Slice_uint8_t){(uint8_t*)"assert(list.push(20))", 21});
  } else {
    test___test_pass();
  }
  if (!(ArrayList_int32_t_push((&list), 30))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 27, (__Slice_uint8_t){(uint8_t*)"assert(list.push(30))", 21});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_size((&list)) == 3))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 28, (__Slice_uint8_t){(uint8_t*)"assert(list.size() == 3)", 24});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_get((&list), 0) == 10))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 29, (__Slice_uint8_t){(uint8_t*)"assert(list.get(0) == 10)", 25});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_get((&list), 1) == 20))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 30, (__Slice_uint8_t){(uint8_t*)"assert(list.get(1) == 20)", 25});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_get((&list), 2) == 30))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 31, (__Slice_uint8_t){(uint8_t*)"assert(list.get(2) == 30)", 25});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_top((&list)) == 30))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 32, (__Slice_uint8_t){(uint8_t*)"assert(list.top() == 30)", 24});
  } else {
    test___test_pass();
  }
  if (!(ArrayList_int32_t_pop((&list)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 33, (__Slice_uint8_t){(uint8_t*)"assert(list.pop())", 18});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_size((&list)) == 2))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 34, (__Slice_uint8_t){(uint8_t*)"assert(list.size() == 2)", 24});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_top((&list)) == 20))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 35, (__Slice_uint8_t){(uint8_t*)"assert(list.top() == 20)", 24});
  } else {
    test___test_pass();
  }
}

void collection_test__arraylist_full(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  ArrayList_int32_t list = {0};
  ArrayList_int32_t_init((&list), (&alloc), 2);
  if (!(ArrayList_int32_t_push((&list), 1))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 43, (__Slice_uint8_t){(uint8_t*)"assert(list.push(1))", 20});
  } else {
    test___test_pass();
  }
  if (!(ArrayList_int32_t_push((&list), 2))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 44, (__Slice_uint8_t){(uint8_t*)"assert(list.push(2))", 20});
  } else {
    test___test_pass();
  }
  if (!(ArrayList_int32_t_is_full((&list)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 45, (__Slice_uint8_t){(uint8_t*)"assert(list.is_full())", 22});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_push((&list), 3) == false))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 46, (__Slice_uint8_t){(uint8_t*)"assert(list.push(3) == false)", 29});
  } else {
    test___test_pass();
  }
}

void collection_test__arraylist_set_clear(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  ArrayList_int32_t list = {0};
  ArrayList_int32_t_init((&list), (&alloc), 4);
  ArrayList_int32_t_push((&list), 1);
  ArrayList_int32_t_push((&list), 2);
  ArrayList_int32_t_set((&list), 0, 99);
  if (!((ArrayList_int32_t_get((&list), 0) == 99))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 57, (__Slice_uint8_t){(uint8_t*)"assert(list.get(0) == 99)", 25});
  } else {
    test___test_pass();
  }
  ArrayList_int32_t_clear((&list));
  if (!(ArrayList_int32_t_is_empty((&list)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 59, (__Slice_uint8_t){(uint8_t*)"assert(list.is_empty())", 23});
  } else {
    test___test_pass();
  }
  if (!((ArrayList_int32_t_size((&list)) == 0))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 60, (__Slice_uint8_t){(uint8_t*)"assert(list.size() == 0)", 24});
  } else {
    test___test_pass();
  }
}

void collection_test__linkedlist_init(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  LinkedList_int32_t list = {0};
  if (!(LinkedList_int32_t_init((&list), (&alloc), 4))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 69, (__Slice_uint8_t){(uint8_t*)"assert(list.init(&alloc, 4))", 28});
  } else {
    test___test_pass();
  }
  if (!(LinkedList_int32_t_is_empty((&list)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 70, (__Slice_uint8_t){(uint8_t*)"assert(list.is_empty())", 23});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_size((&list)) == 0))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 71, (__Slice_uint8_t){(uint8_t*)"assert(list.size() == 0)", 24});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_capacity((&list)) == 4))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 72, (__Slice_uint8_t){(uint8_t*)"assert(list.capacity() == 4)", 28});
  } else {
    test___test_pass();
  }
}

void collection_test__linkedlist_push_back_pop_front(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  LinkedList_int32_t list = {0};
  LinkedList_int32_t_init((&list), (&alloc), 4);
  if (!(LinkedList_int32_t_push_back((&list), 10))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 80, (__Slice_uint8_t){(uint8_t*)"assert(list.push_back(10))", 26});
  } else {
    test___test_pass();
  }
  if (!(LinkedList_int32_t_push_back((&list), 20))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 81, (__Slice_uint8_t){(uint8_t*)"assert(list.push_back(20))", 26});
  } else {
    test___test_pass();
  }
  if (!(LinkedList_int32_t_push_back((&list), 30))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 82, (__Slice_uint8_t){(uint8_t*)"assert(list.push_back(30))", 26});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_size((&list)) == 3))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 83, (__Slice_uint8_t){(uint8_t*)"assert(list.size() == 3)", 24});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_front((&list)) == 10))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 84, (__Slice_uint8_t){(uint8_t*)"assert(list.front() == 10)", 26});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_back((&list)) == 30))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 85, (__Slice_uint8_t){(uint8_t*)"assert(list.back() == 30)", 25});
  } else {
    test___test_pass();
  }
  if (!(LinkedList_int32_t_pop_front((&list)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 86, (__Slice_uint8_t){(uint8_t*)"assert(list.pop_front())", 24});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_front((&list)) == 20))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 87, (__Slice_uint8_t){(uint8_t*)"assert(list.front() == 20)", 26});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_size((&list)) == 2))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 88, (__Slice_uint8_t){(uint8_t*)"assert(list.size() == 2)", 24});
  } else {
    test___test_pass();
  }
}

void collection_test__linkedlist_push_front_pop_back(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  LinkedList_int32_t list = {0};
  LinkedList_int32_t_init((&list), (&alloc), 4);
  if (!(LinkedList_int32_t_push_front((&list), 10))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 96, (__Slice_uint8_t){(uint8_t*)"assert(list.push_front(10))", 27});
  } else {
    test___test_pass();
  }
  if (!(LinkedList_int32_t_push_front((&list), 20))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 97, (__Slice_uint8_t){(uint8_t*)"assert(list.push_front(20))", 27});
  } else {
    test___test_pass();
  }
  if (!(LinkedList_int32_t_push_front((&list), 30))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 98, (__Slice_uint8_t){(uint8_t*)"assert(list.push_front(30))", 27});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_front((&list)) == 30))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 99, (__Slice_uint8_t){(uint8_t*)"assert(list.front() == 30)", 26});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_back((&list)) == 10))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 100, (__Slice_uint8_t){(uint8_t*)"assert(list.back() == 10)", 25});
  } else {
    test___test_pass();
  }
  if (!(LinkedList_int32_t_pop_back((&list)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 101, (__Slice_uint8_t){(uint8_t*)"assert(list.pop_back())", 23});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_back((&list)) == 20))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 102, (__Slice_uint8_t){(uint8_t*)"assert(list.back() == 20)", 25});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_size((&list)) == 2))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 103, (__Slice_uint8_t){(uint8_t*)"assert(list.size() == 2)", 24});
  } else {
    test___test_pass();
  }
}

void collection_test__linkedlist_full_reuse(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  LinkedList_int32_t list = {0};
  LinkedList_int32_t_init((&list), (&alloc), 2);
  if (!(LinkedList_int32_t_push_back((&list), 1))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 111, (__Slice_uint8_t){(uint8_t*)"assert(list.push_back(1))", 25});
  } else {
    test___test_pass();
  }
  if (!(LinkedList_int32_t_push_back((&list), 2))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 112, (__Slice_uint8_t){(uint8_t*)"assert(list.push_back(2))", 25});
  } else {
    test___test_pass();
  }
  if (!(LinkedList_int32_t_is_full((&list)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 113, (__Slice_uint8_t){(uint8_t*)"assert(list.is_full())", 22});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_push_back((&list), 3) == false))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 114, (__Slice_uint8_t){(uint8_t*)"assert(list.push_back(3) == false)", 34});
  } else {
    test___test_pass();
  }
  LinkedList_int32_t_pop_front((&list));
  if (!(LinkedList_int32_t_push_back((&list), 99))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 117, (__Slice_uint8_t){(uint8_t*)"assert(list.push_back(99))", 26});
  } else {
    test___test_pass();
  }
  if (!((LinkedList_int32_t_back((&list)) == 99))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 118, (__Slice_uint8_t){(uint8_t*)"assert(list.back() == 99)", 25});
  } else {
    test___test_pass();
  }
}

void collection_test__ringbuffer_init(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  RingBuffer_int32_t rb = {0};
  if (!(RingBuffer_int32_t_init((&rb), (&alloc), 4))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 127, (__Slice_uint8_t){(uint8_t*)"assert(rb.init(&alloc, 4))", 26});
  } else {
    test___test_pass();
  }
  if (!(RingBuffer_int32_t_is_empty((&rb)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 128, (__Slice_uint8_t){(uint8_t*)"assert(rb.is_empty())", 21});
  } else {
    test___test_pass();
  }
  if (!((RingBuffer_int32_t_size((&rb)) == 0))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 129, (__Slice_uint8_t){(uint8_t*)"assert(rb.size() == 0)", 22});
  } else {
    test___test_pass();
  }
  if (!((RingBuffer_int32_t_capacity((&rb)) == 4))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 130, (__Slice_uint8_t){(uint8_t*)"assert(rb.capacity() == 4)", 26});
  } else {
    test___test_pass();
  }
}

void collection_test__ringbuffer_push_pop(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  RingBuffer_int32_t rb = {0};
  RingBuffer_int32_t_init((&rb), (&alloc), 4);
  if (!(RingBuffer_int32_t_push((&rb), 10))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 138, (__Slice_uint8_t){(uint8_t*)"assert(rb.push(10))", 19});
  } else {
    test___test_pass();
  }
  if (!(RingBuffer_int32_t_push((&rb), 20))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 139, (__Slice_uint8_t){(uint8_t*)"assert(rb.push(20))", 19});
  } else {
    test___test_pass();
  }
  if (!(RingBuffer_int32_t_push((&rb), 30))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 140, (__Slice_uint8_t){(uint8_t*)"assert(rb.push(30))", 19});
  } else {
    test___test_pass();
  }
  if (!((RingBuffer_int32_t_size((&rb)) == 3))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 141, (__Slice_uint8_t){(uint8_t*)"assert(rb.size() == 3)", 22});
  } else {
    test___test_pass();
  }
  if (!((RingBuffer_int32_t_peek((&rb)) == 10))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 142, (__Slice_uint8_t){(uint8_t*)"assert(rb.peek() == 10)", 23});
  } else {
    test___test_pass();
  }
  if (!(RingBuffer_int32_t_pop((&rb)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 143, (__Slice_uint8_t){(uint8_t*)"assert(rb.pop())", 16});
  } else {
    test___test_pass();
  }
  if (!((RingBuffer_int32_t_peek((&rb)) == 20))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 144, (__Slice_uint8_t){(uint8_t*)"assert(rb.peek() == 20)", 23});
  } else {
    test___test_pass();
  }
  if (!((RingBuffer_int32_t_size((&rb)) == 2))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 145, (__Slice_uint8_t){(uint8_t*)"assert(rb.size() == 2)", 22});
  } else {
    test___test_pass();
  }
}

void collection_test__ringbuffer_wrap_around(void) {
  Allocator alloc = {0};
  Allocator_init((&alloc), 512);
  RingBuffer_int32_t rb = {0};
  RingBuffer_int32_t_init((&rb), (&alloc), 3);
  RingBuffer_int32_t_push((&rb), 1);
  RingBuffer_int32_t_push((&rb), 2);
  RingBuffer_int32_t_push((&rb), 3);
  if (!(RingBuffer_int32_t_is_full((&rb)))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 156, (__Slice_uint8_t){(uint8_t*)"assert(rb.is_full())", 20});
  } else {
    test___test_pass();
  }
  if (!((RingBuffer_int32_t_push((&rb), 4) == false))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 157, (__Slice_uint8_t){(uint8_t*)"assert(rb.push(4) == false)", 27});
  } else {
    test___test_pass();
  }
  RingBuffer_int32_t_pop((&rb));
  if (!(RingBuffer_int32_t_push((&rb), 4))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 159, (__Slice_uint8_t){(uint8_t*)"assert(rb.push(4))", 18});
  } else {
    test___test_pass();
  }
  if (!((RingBuffer_int32_t_peek((&rb)) == 2))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 160, (__Slice_uint8_t){(uint8_t*)"assert(rb.peek() == 2)", 22});
  } else {
    test___test_pass();
  }
  RingBuffer_int32_t_pop((&rb));
  if (!((RingBuffer_int32_t_peek((&rb)) == 3))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 162, (__Slice_uint8_t){(uint8_t*)"assert(rb.peek() == 3)", 22});
  } else {
    test___test_pass();
  }
  RingBuffer_int32_t_pop((&rb));
  if (!((RingBuffer_int32_t_peek((&rb)) == 4))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 164, (__Slice_uint8_t){(uint8_t*)"assert(rb.peek() == 4)", 22});
  } else {
    test___test_pass();
  }
  if (!((RingBuffer_int32_t_size((&rb)) == 1))) {
    test___test_fail((__Slice_uint8_t){(uint8_t*)"/Users/sang/Dev/panda-io/micro-panda-dart/micro-panda/std/src/collection_test.mpd", 81}, 165, (__Slice_uint8_t){(uint8_t*)"assert(rb.size() == 1)", 22});
  } else {
    test___test_pass();
  }
}

int main(void) {
    test___test_begin((__Slice_uint8_t){(uint8_t*)"arraylist_init", 14});
    collection_test__arraylist_init();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"arraylist_push_pop", 18});
    collection_test__arraylist_push_pop();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"arraylist_full", 14});
    collection_test__arraylist_full();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"arraylist_set_clear", 19});
    collection_test__arraylist_set_clear();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"linkedlist_init", 15});
    collection_test__linkedlist_init();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"linkedlist_push_back_pop_front", 30});
    collection_test__linkedlist_push_back_pop_front();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"linkedlist_push_front_pop_back", 30});
    collection_test__linkedlist_push_front_pop_back();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"linkedlist_full_reuse", 21});
    collection_test__linkedlist_full_reuse();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"ringbuffer_init", 15});
    collection_test__ringbuffer_init();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"ringbuffer_push_pop", 19});
    collection_test__ringbuffer_push_pop();
    test___test_end();
    test___test_begin((__Slice_uint8_t){(uint8_t*)"ringbuffer_wrap_around", 22});
    collection_test__ringbuffer_wrap_around();
    test___test_end();
    return test___report();
}

