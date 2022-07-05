#import <openssl/pem.h>
#import <openssl/ssl.h>
#import <openssl/rsa.h>
#import <openssl/evp.h>
#import <openssl/bio.h>
#import <openssl/err.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <stdbool.h>
#import "lua.hpp"

int luaopen_minirsa(lua_State *L);
int padding = RSA_PKCS1_PADDING;
int max_len = 128;

static RSA *createRSA(unsigned char *key, int public) {
    RSA *rsa = NULL;
    BIO *keybio;
    keybio = BIO_new_mem_buf(key, -1);
    if (keybio == NULL) return 0;
    if (public) rsa = PEM_read_bio_RSA_PUBKEY(keybio, &rsa, NULL, NULL);
    else rsa = PEM_read_bio_RSAPrivateKey(keybio, &rsa, NULL, NULL);
    return rsa;
}

static int public_encrypt(unsigned char *data, int data_len, unsigned char *key, unsigned char *encrypted) {
    RSA *rsa = createRSA(key, 1);
    int result = RSA_public_encrypt(data_len, data, encrypted, rsa, padding);
    return result;
}
static int minirsa_public_encrypt(lua_State *L) {
    size_t data_len, key_len;
    unsigned char *orig_data = (unsigned char *) luaL_checklstring(L, 1, &data_len);
    if (data_len > max_len - 11) {
        luaL_error(L, "Input data is too large (> %zu bytes).", max_len - 11);
    }
    unsigned char *orig_key = (unsigned char *) luaL_checklstring(L, 2, &key_len);
    unsigned char *output_buffer = (unsigned char *) malloc(max_len + 1);
    memset(output_buffer, 0x0, max_len + 1);
    if (public_encrypt(orig_data, (int) data_len, orig_key, output_buffer) >= 0) {
        lua_pushlstring(L, (const char *) output_buffer, max_len);
    } else {
        lua_pushboolean(L, false);
    }
    free(output_buffer);
    return 1;
}

static int private_decrypt(unsigned char *enc_data, int data_len, unsigned char *key, unsigned char *decrypted) {
    RSA *rsa = createRSA(key, 0);
    int result = RSA_private_decrypt(data_len, enc_data, decrypted, rsa, padding);
    return result;
}
static int minirsa_private_decrypt(lua_State *L) {
    size_t data_len, key_len;
    unsigned char *enc_data = (unsigned char *) luaL_checklstring(L, 1, &data_len);
    unsigned char *enc_key = (unsigned char *) luaL_checklstring(L, 2, &key_len);
    unsigned char *output_buffer = (unsigned char *) malloc(max_len + 1);
    memset(output_buffer, 0x0, max_len + 1);
    if (private_decrypt(enc_data, (int) data_len, enc_key, output_buffer) >= 0) {
        lua_pushlstring(L, (const char *) output_buffer, max_len);
    } else {
        lua_pushboolean(L, false);
    }
    free(output_buffer);
    return 1;
}

static int private_encrypt(unsigned char *data, int data_len, unsigned char *key, unsigned char *encrypted) {
    RSA *rsa = createRSA(key, 0);
    int result = RSA_private_encrypt(data_len, data, encrypted, rsa, padding);
    return result;
}
static int minirsa_private_encrypt(lua_State *L) {
    size_t data_len, key_len;
    unsigned char *orig_data = (unsigned char *) luaL_checklstring(L, 1, &data_len);
    if (data_len > max_len - 11) {
        luaL_error(L, "Input data is too large (> %zu bytes).", max_len - 11);
    }
    unsigned char *orig_key = (unsigned char *) luaL_checklstring(L, 2, &key_len);
    unsigned char *output_buffer = (unsigned char *) malloc(max_len + 1);
    memset(output_buffer, 0x0, max_len + 1);
    if (private_encrypt(orig_data, (int) data_len, orig_key, output_buffer) >= 0) {
        lua_pushlstring(L, (const char *) output_buffer, max_len);
    } else {
        lua_pushboolean(L, false);
    }
    free(output_buffer);
    return 1;
}

static int public_decrypt(unsigned char *enc_data, int data_len, unsigned char *key, unsigned char *decrypted) {
    RSA *rsa = createRSA(key, 1);
    int result = RSA_public_decrypt(data_len, enc_data, decrypted, rsa, padding);
    return result;
}
static int minirsa_public_decrypt(lua_State *L) {
    size_t data_len, key_len;
    unsigned char *enc_data = (unsigned char *) luaL_checklstring(L, 1, &data_len);
    unsigned char *enc_key = (unsigned char *) luaL_checklstring(L, 2, &key_len);
    unsigned char *output_buffer = (unsigned char *) malloc(max_len + 1);
    memset(output_buffer, 0x0, max_len + 1);
    if (public_decrypt(enc_data, (int) data_len, enc_key, output_buffer) >= 0) {
        lua_pushlstring(L, (const char *) output_buffer, max_len);
    } else {
        lua_pushboolean(L, false);
    }
    free(output_buffer);
    return 1;
}

static const luaL_Reg minirsa_lib[] = {
        {"public_encrypt",  minirsa_public_encrypt},
        {"private_decrypt", minirsa_private_decrypt},
        {"private_encrypt", minirsa_private_encrypt},
        {"public_decrypt",  minirsa_public_decrypt},
        {NULL, NULL}
};

int luaopen_minirsa(lua_State *L) {
    luaL_newlib(L, minirsa_lib);
    return 1;
}
