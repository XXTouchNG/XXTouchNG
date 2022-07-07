#ifndef xxt32_h
#define xxt32_h

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

static uint8_t const kXXTModelFormatVersion = 0xe1;
static uint32_t const kXXTModelBlockLength = 4096;
struct xxt_hdr_32 {
    uint8_t magic[4];   // 4
    uint8_t version;    // 1
    uint8_t flag;       // 1
    uint16_t data_hash; // 2, the hash of data
    uint32_t data_len;  // 4
};
struct xxt_32 {
    struct xxt_hdr_32 header;
    void *data;
};
struct xxt_block_hdr_32 {
    uint16_t block_hash; // 2, the hash of raw block data
    uint8_t rand[16]; // 16
    uint32_t block_len; // 4
};

typedef struct xxt_32 xxt_32;
typedef struct xxt_hdr_32 xxt_hdr_32;
typedef struct xxt_block_hdr_32 xxt_block_hdr_32;

xxt_32 *XXTCreateWithData(const void *data, uint32_t length);
xxt_32 *XXTCreateWithContentsOfFile(const char *path);

int XXTWriteToFile(const char *path, xxt_32 *xxt);
void XXTCopyRawData(xxt_32 *xxt, void **ptr, uint32_t *total);

void XXTRelease(xxt_32 *xxt);

#ifdef __cplusplus
}
#endif

#endif /* xxt32_h */
