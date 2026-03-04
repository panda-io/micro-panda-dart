



var my_array: i32[10] -> declares an array of 10 integers (will be created statically, allocator is not required)


when pass to method, length is not specified.

fun process(another_array: i32[]):
    pass


inside array:    this is length field + continues data space. 

we fetch acount by my_array.size()