
no namespace, no package. like Dart, micro panda use file local as the lib path




import a file:

import util.math

var min_value := math.min(1, 2)



import symbol:

import util.math::min

var min_value := min(1, 2)



use alias

import util.math as m

var min_value := m.min(1, 2)


import util.math::min as min

var min_value := min(1, 2)






visibilty, no public / private modifier


fun public_method -> public

fun _private_method -> private function start with "_"

the same to vars