cmake_minimum_required(VERSION 3.18)
project(codec2_flutter VERSION 0.1.0)

# ── Codec2 source path ──────────────────────────────────────────────────────
# Expects the drowe67/codec2 repo as a sibling to this plugin:
#   packages/codec2_flutter/src/codec2/   (git submodule)
#
# To initialise: from the repo root run:
#   git submodule add https://github.com/drowe67/codec2.git packages/codec2_flutter/src/codec2
#   git submodule update --init --recursive
set(CODEC2_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../src/codec2")
set(CODEC2_SRC  "${CODEC2_ROOT}/src")
set(CODEC2_GEN  "${CMAKE_CURRENT_SOURCE_DIR}/../src/codec2_generated")

# ── Codec2 core source files ─────────────────────────────────────────────────
# Only the files required for MODE_700C, MODE_1200, MODE_2400.
set(CODEC2_SOURCES
    ${CODEC2_SRC}/codec2.c
    ${CODEC2_SRC}/lpc.c
    ${CODEC2_SRC}/lsp.c
    ${CODEC2_SRC}/quantise.c
    ${CODEC2_SRC}/phase.c
    ${CODEC2_SRC}/postfilter.c
    ${CODEC2_SRC}/sine.c
    ${CODEC2_SRC}/interp.c
    ${CODEC2_SRC}/nlp.c
    ${CODEC2_SRC}/pack.c
    ${CODEC2_SRC}/dump.c
    ${CODEC2_SRC}/mbest.c
    ${CODEC2_SRC}/newamp1.c
    ${CODEC2_SRC}/codec2_fft.c
    ${CODEC2_SRC}/kiss_fft.c
    ${CODEC2_SRC}/kiss_fftr.c
    ${CODEC2_GEN}/codebook.c
    ${CODEC2_GEN}/codebookd.c
    ${CODEC2_GEN}/codebookge.c
    ${CODEC2_GEN}/codebookjmv.c
    ${CODEC2_GEN}/codebooknewamp1.c
    ${CODEC2_GEN}/codebooknewamp1_energy.c
    ${CODEC2_GEN}/codebooknewamp2.c
    ${CODEC2_GEN}/codebooknewamp2_energy.c
)

add_library(codec2_flutter SHARED
    src/main/cpp/codec2_flutter.c
    ${CODEC2_SOURCES}
)

target_include_directories(codec2_flutter PRIVATE
    ${CODEC2_SRC}
    ${CODEC2_GEN}
)

target_compile_definitions(codec2_flutter PRIVATE
    DUMP=0          # disable debug dump file output
)

find_library(log-lib log)
target_link_libraries(codec2_flutter ${log-lib} m)
