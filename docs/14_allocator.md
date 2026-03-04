

everything in micro panda is static


import device::Device


val my_device : &Device = Device()


we can hold either reference or value for scalar type, but only reference for class type


array is a special built in class, we allocate space with declare. you can pass array directly with explicit use referecnce &




in order to reuse memory for different task , and allocate class in stack, we introduce allocator

val cache : u8[1024]
val allocator := Allocator(cache)

val device : &Device = allocator.allocate(sizeof(Device))

after we done with everything, invoke allocator.free(), it will free all allocated space (no fragmentation), and it can be reused.