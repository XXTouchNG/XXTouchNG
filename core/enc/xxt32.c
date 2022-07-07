#include <xxt32.h>
#include <assert.h>
#include <xxtea.h>
#include <crc.h>

#define MIN(a,b) (a) < (b) ? (a) : (b)

void arc4random_buf_safe(void *buf, size_t nbytes) {
    arc4random_buf(buf, nbytes);
    unsigned char *buffer = buf;
    for (size_t i = 0; i < nbytes; i++) {
        if (*(buffer + i) == 0x0) {
            *(buffer + i) = 0xFF;
        }
    }
}

xxt_32 *XXTCreateWithData(const void *data, uint32_t length)
{
    assert(data);
    
    // crc init
    crcInit();
    
    xxt_32 *xxt = malloc(sizeof(xxt_32));
    assert(xxt);
    
    // magic
    xxt->header.magic[0] = 0xe7;
    xxt->header.magic[1] = 0x58; // X
    xxt->header.magic[2] = 0x58; // X
    xxt->header.magic[3] = 0x54; // T
    
    if (0 == memcmp(xxt, data, sizeof(xxt->header.magic))) {
        
        // already encrypted, load it
        
        // load header
        memcpy(xxt, data, sizeof(xxt_hdr_32));
        
        // check version
        if (xxt->header.version > kXXTModelFormatVersion) {
            free(xxt);
            return NULL;
        }
        
        // copy data
        uint32_t data_len = length - (sizeof(xxt_hdr_32));
        void *out_data = malloc(data_len);
        assert(out_data);
        memcpy(out_data, data + sizeof(xxt_hdr_32), data_len);
        
        // check hash
        crc data_hash = crcFast(out_data, data_len);
        if (data_hash != xxt->header.data_hash) {
            free(out_data);
            free(xxt);
            return NULL;
        }
        
        xxt->data = out_data;
        return xxt;
        
    } else {
        
        // version and flag
        xxt->header.version = kXXTModelFormatVersion;
        xxt->header.flag = 0xFF;
        
        uint32_t len = 0; // finished raw length
        uint32_t total = length; // total raw length
        uint32_t data_len = 0; // finished out length
        
        void *out_data = malloc(sizeof(xxt_block_hdr_32)); // out data
        assert(out_data);
        
        while (len < total) {
            
            // block header
            xxt_block_hdr_32 *block_hdr = malloc(sizeof(xxt_block_hdr_32));
            assert(block_hdr);
            
            block_hdr->block_len = 0;
            
            // rand
            uint8_t rand[sizeof(block_hdr->rand)];
            memset(rand, 0xFF, sizeof(block_hdr->rand));
            arc4random_buf_safe(rand, sizeof(block_hdr->rand));
            memcpy(block_hdr->rand, rand, sizeof(block_hdr->rand));
            
            uint32_t enc_len = MIN(kXXTModelBlockLength, length - len);
            
            // crc hash
            crc block_hash = crcFast(data + len, (int)enc_len);
            block_hdr->block_hash = block_hash;
            
            // encrypt raw block
            size_t enc_out_len;
            void *enc_data = xxtea_encrypt(data + len, enc_len, rand, &enc_out_len);
            assert(enc_data);
            block_hdr->block_len += enc_out_len;
            len += enc_len;
            
            // realloc memory
            uint32_t new_len = data_len + sizeof(xxt_block_hdr_32);
            new_len += enc_out_len;
            out_data = realloc(out_data, new_len);
            
            // write block header
            memcpy(out_data + data_len, block_hdr, sizeof(xxt_block_hdr_32));
            data_len += sizeof(xxt_block_hdr_32);
            
            // write block data
            memcpy(out_data + data_len, enc_data, enc_out_len);
            data_len += enc_out_len;
            
            // free memory
            free(enc_data);
            free(block_hdr);
            
        }
        
        crc data_hash = crcFast(out_data, (int)data_len);
        xxt->header.data_hash = data_hash;
        xxt->header.data_len = data_len;
        if (data_len == 0) {
            xxt->data = NULL;
            free(out_data);
        } else {
            xxt->data = out_data;
        }
        
        return xxt;
    }
    
}

int XXTWriteToFile(const char *path, xxt_32 *xxt) {
    assert(xxt);
    assert(xxt->data);
    FILE *fp = fopen(path, "wb");
    if (!fp) return -1;
    fwrite(xxt, sizeof(xxt_hdr_32), 1, fp);
    fwrite(xxt->data, xxt->header.data_len, 1, fp);
    return fclose(fp);
}

void XXTRelease(xxt_32 *xxt) {
    assert(xxt);
    if (xxt->data)
    { free(xxt->data); xxt->data = NULL; }
    free(xxt);
}

void XXTCopyRawData(xxt_32 *xxt, void **ptr, uint32_t *total) {
    assert(xxt);
    assert(ptr);
    assert(total);
    
    uint32_t len = 0;
    uint32_t out_len = 0;
    
    void *read_data = malloc(kXXTModelBlockLength);
    assert(read_data);
    
    xxt_block_hdr_32 block_header;
    while (len < xxt->header.data_len) {
        
        // read block header
        memcpy(&block_header, xxt->data + len, sizeof(xxt_block_hdr_32));
        len += sizeof(xxt_block_hdr_32);
        
        // decrypt block
        size_t dec_out_len;
        void *dec_data = xxtea_decrypt(xxt->data + len, block_header.block_len, block_header.rand, &dec_out_len);
        if (!dec_data) {
            goto clean2;
        }
        len += block_header.block_len;
        
        // check hash
        crc block_hash = crcFast(dec_data, (int)dec_out_len);
        if (block_hash != block_header.block_hash) {
            free(dec_data);
            goto clean2;
        }
        
        // realloc memoty
        uint32_t new_len = out_len + (uint32_t)dec_out_len;
        read_data = realloc(read_data, new_len);
        
        // copy raw data
        memcpy(read_data + out_len, dec_data, dec_out_len);
        out_len += dec_out_len;
        
        free(dec_data);
    }
    
    *ptr = read_data;
    *total = out_len;
    
    return;
    
clean2:
    free(read_data);
    
}

xxt_32 *XXTCreateWithContentsOfFile(const char *path) {
    FILE *pTest = fopen(path, "rb");
    assert(pTest);
    
    fseek(pTest, 0, SEEK_END);
    size_t lSize = ftell(pTest);
    rewind(pTest);
    
    void *buffer = malloc(lSize);
    assert(buffer);
    fread(buffer, 1, lSize, pTest);
    
    fclose(pTest);
    
    xxt_32 *obj = XXTCreateWithData(buffer, (uint32_t)lSize);
    free(buffer);
    
    return obj;
}
