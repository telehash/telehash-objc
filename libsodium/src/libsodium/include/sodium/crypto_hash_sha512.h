#ifndef crypto_hash_sha512_H
#define crypto_hash_sha512_H

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#include "export.h"

#define crypto_hash_sha512_BYTES 64U
#define crypto_hash_sha512_BLOCKBYTES 128U

#ifdef __cplusplus
# if __GNUC__
#  pragma GCC diagnostic ignored "-Wlong-long"
# endif
extern "C" {
#endif

typedef struct crypto_hash_sha512_state {
    uint64_t      state[8];
    uint64_t      count[2];
    unsigned char buf[128];
} crypto_hash_sha512_state;

SODIUM_EXPORT
size_t crypto_hash_sha512_bytes(void);

SODIUM_EXPORT
const char * crypto_hash_sha512_primitive(void);

SODIUM_EXPORT
int crypto_hash_sha512(unsigned char *,const unsigned char *,unsigned long long);

SODIUM_EXPORT
int crypto_hash_sha512_init(crypto_hash_sha512_state *state);

SODIUM_EXPORT
int crypto_hash_sha512_update(crypto_hash_sha512_state *state,
                              const unsigned char *in,
                              unsigned long long inlen);

SODIUM_EXPORT
int crypto_hash_sha512_final(crypto_hash_sha512_state *state,
                             unsigned char *out);

#ifdef __cplusplus
}
#endif

#define crypto_hash_sha512_cp crypto_hash_sha512

#endif
