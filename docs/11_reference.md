


reference is pointer indeed, but some grammar sugar


var int32 := 123
var int32_ref: &i32 = &int32




for scalar types
we can pass either value or ref to the function


for class type and union enum (not value enum, like &Expression)
we can pass only reference to the function (no struct copy)



for the array of classes/union enum, we fetch only reference by index (avoid struct copy)

var expressions : Expression[10]

var expr1: &Expression = expressions[0]
var expr2: &Expression = expressions[1]