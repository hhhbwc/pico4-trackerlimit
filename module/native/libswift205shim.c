/* libswift205shim.so — v1 (with logging)
 * Provides getSwiftTrackerInfoVector for com.pvr.swift 2.0.5 on firmware whose
 * tracking stack lacks the symbol. Loaded via DT_NEEDED of libtrackingclient.pxr.so.
 */
typedef unsigned long u64;
typedef int i32;

#define RTLD_NOW 2
#define RTLD_NOLOAD 4

extern void* dlopen(const char* name, int flags);
extern void* dlsym(void* handle, const char* sym);
extern void* malloc(u64 size);
extern void free(void* p);
extern int __android_log_print(int prio, const char* tag, const char* fmt, ...);

#define ITEM 0x48
#define NSLOT 3
#define TAG "Swift205Shim"

typedef struct { char* begin; char* end; char* cap; } Vec;

static void mc(char* d, const char* s, u64 n) {
    u64 i;
    for (i = 0; i < n; i++) d[i] = s[i];
}

static i32 vec_push(Vec* v, const char* item) {
    if (v->end + ITEM > v->cap) {
        u64 used = (u64)(v->end - v->begin);
        u64 cap  = (u64)(v->cap - v->begin);
        u64 ncap = cap + cap / 2;
        char* nb;
        if (ncap < used + ITEM) ncap = used + ITEM * 16;
        nb = (char*)malloc(ncap);
        if (!nb) return -1;
        mc(nb, v->begin, used);
        if (v->begin) free(v->begin);
        v->begin = nb;
        v->end   = nb + used;
        v->cap   = nb + ncap;
    }
    mc(v->end, item, ITEM);
    v->end += ITEM;
    return 0;
}

__attribute__((visibility("default")))
i32 getSwiftTrackerInfoVector(void* self, Vec* out) {
    static void* h;
    static i32 (*real)(void*, void*);
    char buf[NSLOT * ITEM];
    i32 i, r;

    if (!real) {
        h = dlopen("libtrackingclient.pxr.so", RTLD_NOW | RTLD_NOLOAD);
        if (!h) h = dlopen("libtrackingclient.pxr.so", RTLD_NOW);
        if (h) real = (i32 (*)(void*, void*))dlsym(h, "getSwiftTrackerInfo");
        __android_log_print(4, TAG, "init: h=%p real=%p (self=%p out=%p)", h, real, self, out);
    }
    if (!real) return -101;

    for (i = 0; i < NSLOT * ITEM; i++) buf[i] = 0;
    r = real(self, buf);
    __android_log_print(4, TAG, "legacy call ret=%d, item0:b0=%d id=%d pos=%d", r,
                        (int)buf[0], (int)buf[8], (int)buf[0x30]);
    if (r != 0) return r;

    for (i = 0; i < NSLOT; i++) {
        if (vec_push(out, buf + i * ITEM) != 0) return -102;
    }
    __android_log_print(4, TAG, "pushed %d items, vec begin=%p end=%p", NSLOT, out->begin, out->end);
    return 0;
}
