#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <openssl/evp.h>

#define SAFELOADER_PREAMBLE_SIZE	0x14

/**
   Salt for the MD5 hash

   Fortunately, TP-LINK seems to use the same salt for most devices which use
   the new image format.
*/
static const uint8_t md5_salt[16] = {
        0x7a, 0x2b, 0x15, 0xed,
        0x9b, 0x98, 0x59, 0x6d,
        0xe5, 0x04, 0xab, 0x44,
        0xac, 0x2a, 0x9f, 0x4e,
};

static int put_md5(uint8_t *md5, const uint8_t *buffer, size_t len) {
        EVP_MD_CTX *ctx = EVP_MD_CTX_new();
        if (!ctx)
                return -1;

        if (EVP_DigestInit_ex(ctx, EVP_md5(), NULL) != 1 ||
            EVP_DigestUpdate(ctx, md5_salt, sizeof(md5_salt)) != 1 ||
            EVP_DigestUpdate(ctx, buffer, len) != 1 ||
            EVP_DigestFinal_ex(ctx, md5, NULL) != 1) {
                EVP_MD_CTX_free(ctx);
                return -1;
        }

        EVP_MD_CTX_free(ctx);
        return 0;
}

/** Stores a uint32 as big endian */
static inline void put32(uint8_t *buf, uint32_t val) {
        buf[0] = val >> 24;
        buf[1] = val >> 16;
        buf[2] = val >> 8;
        buf[3] = val;
}

int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <firmware>\n", argv[0]);
        return 1;
    }
    FILE *fp = fopen(argv[1], "rb");
    if (fp == NULL) {
        fprintf(stderr, "File does not exist: %s\nUsage: %s <firmware>\n", argv[1], argv[0]);
        return 1;
    }
    if (fseek(fp, 0, SEEK_END) != 0) {
        fprintf(stderr, "Error: fseek failed on %s\n", argv[1]);
        fclose(fp);
        return 1;
    }
    long raw_size = ftell(fp);
    if (raw_size < (long)SAFELOADER_PREAMBLE_SIZE) {
        fprintf(stderr, "Error: file too small (%ld bytes)\n", raw_size);
        fclose(fp);
        return 1;
    }
    if ((uintmax_t)raw_size > UINT32_MAX) {
        fprintf(stderr, "Error: firmware exceeds the 32-bit length field\n");
        fclose(fp);
        return 1;
    }
    size_t file_size = (size_t)raw_size;
    uint8_t *image = malloc(file_size);
    if (!image) {
        fprintf(stderr, "Error: malloc(%zu) failed\n", file_size);
        fclose(fp);
        return 1;
    }
    if (fseek(fp, 0, SEEK_SET) != 0 || fread(image, 1, file_size, fp) != file_size) {
        fprintf(stderr, "Error: failed to read file %s\n", argv[1]);
        free(image);
        fclose(fp);
        return 1;
    }
    fclose(fp);

    // write file length to the first 4 byte in network byte order
    put32(image, (uint32_t)file_size);

    // write md5
    if (put_md5(image + 0x04, image + SAFELOADER_PREAMBLE_SIZE, file_size - SAFELOADER_PREAMBLE_SIZE) != 0) {
        fprintf(stderr, "Error: failed to calculate MD5 digest\n");
        free(image);
        return 1;
    }

    fp = fopen(argv[1], "wb");
    if (fp == NULL) {
        fprintf(stderr, "File not writable: %s\n", argv[1]);
        free(image);
        return 1;
    }

    if (fwrite(image, 1, file_size, fp) != file_size) {
        fprintf(stderr, "Error: failed to write updated firmware\n");
        free(image);
        fclose(fp);
        return 1;
    }

    if (fclose(fp) != 0) {
        fprintf(stderr, "Error: failed to flush updated firmware\n");
        free(image);
        return 1;
    }
    free(image);
    return 0;
}
