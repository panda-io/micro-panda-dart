

var:  variable
val:  variable, but cannot be assigned after initialization
const: compile time constant value




var my_int: i32 = 0
var my_float: f32 = 1.0
val no_changed = 1

no_changed = 2 -> compile time exception

const MAX_TASK = 8 -> compile time constant value

if no type specified for int, it will use i32
if no type specified for float, it will use f32