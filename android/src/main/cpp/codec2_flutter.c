/**
 * codec2_flutter.c — thin shim that re-exports Codec2 symbols so they are
 * visible to Dart FFI via DynamicLibrary.open('libcodec2_flutter.so').
 *
 * All codec2_* functions are compiled directly into this .so (from the
 * CMakeLists.txt source list), so no re-export is strictly necessary.
 * This file exists as an explicit hook to confirm the symbols are linked.
 */
#include "codec2.h"

/* Force the linker to keep all codec2 symbols visible */
void *_codec2_flutter_keep_symbols(void) {
    return (void *)codec2_create;
}
