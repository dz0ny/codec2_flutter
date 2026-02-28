// codec2_amalgam.c — Unity build of all Codec2 sources needed for the Flutter FFI plugin.
// CocoaPods only compiles files inside the pod's own directory tree, so we include
// the upstream sources via relative paths from here.
//
// Codec2 source lives at:  packages/codec2_flutter/src/codec2/src/
// This file lives at:      packages/codec2_flutter/ios/Classes/
// Relative path from here: ../../src/codec2/src/

#define DUMP 0       // disable file-based debug dump in codec2
#define CORTEX_M4 0  // not on an ARM Cortex-M4

#include "../../src/codec2/src/codec2.c"
#include "../../src/codec2/src/lpc.c"
#include "../../src/codec2/src/lsp.c"
#include "../../src/codec2/src/quantise.c"
#include "../../src/codec2/src/phase.c"
#include "../../src/codec2/src/postfilter.c"
#include "../../src/codec2/src/sine.c"
#include "../../src/codec2/src/interp.c"
#include "../../src/codec2/src/nlp.c"
#include "../../src/codec2/src/pack.c"
#include "../../src/codec2/src/dump.c"
#include "../../src/codec2/src/mbest.c"
#include "../../src/codec2/src/newamp1.c"

// codec2_fft.c, kiss_fft.c, and kiss_fftr.c are in separate translation units
// (codec2_fft_wrap.c / kiss_fft_wrap.c / kiss_fftr_wrap.c) because _kiss_fft_guts.h
// has no include guard and would cause redefinition of kiss_fft_state if included twice.

// The 8 codebook*.c files are also compiled as separate TUs (codebook.c, codebookd.c, ...)
// because generate_codebook emits non-static 'codes0'/'codes1'/... arrays that would
// collide if all codebooks were included in a single translation unit.
