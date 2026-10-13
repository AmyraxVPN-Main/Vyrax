// SPDX-License-Identifier: MIT
package main
/*
#include <stdlib.h>
*/
import "C"
import "unsafe"
import "vyrax/engine"

//export VyraxInvoke
func VyraxInvoke(request *C.char)*C.char {return C.CString(engine.Invoke(C.GoString(request)))}
//export VyraxFree
func VyraxFree(value *C.char){C.free(unsafe.Pointer(value))}
func main(){}
