/*
 * C syntax stress file. Lexing only.
 * /* C block comments do not nest: this */
int after_first_close = 1; /* the line above closed the comment early */

#include <stdio.h>
#include <stdlib.h>
#include "local/header.h"
#  include   <sys/types.h>
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define STR(x) #x
#define CONCAT(a, b) a##b
#define LONG_MACRO(x)            \
    do {                         \
        printf("%d\n", (x));     \
    } while (0)
#if defined(__linux__) && !defined(NDEBUG) // comment after a directive
#  define PLATFORM "linux"
#elif _WIN32 /* block comment in a directive */
#  define PLATFORM "windows"
#else
#  error "unsupported platform"
#endif
#pragma once

typedef unsigned long long u64;

static const u64 hex = 0xDEADBEEFULL;
static const int digit_sep = 1'000'000;   /* C23 / C++14 digit separators */
static const float f = 3.14f;
static const double d = 1.5e-10;
static const double leading = .25;
static const long double ld = 6.02e23L;
static const unsigned mask = 0x00'FF'00'FFu;

struct node {
    int value;
    struct node *next;
    union {
        char bytes[sizeof(int)];
        int  word;
    } u;
    unsigned flag : 1;
};

enum colour { RED = 1, GREEN, BLUE = 0x10 };

static inline int strings(void) {
    const char *s = "escapes: \n \t \" \\ \x41 \101 é";
    const char *adjacent = "first " "second "
                           "third";
    const char *percent = "%-10s|%08.3f|%%";
    char c = 'a';
    char esc = '\'';
    char nul = '\0';
    char hexc = '\x7f';
    int multi = 'ab'; /* multi-char constant */
    return s[0] + adjacent[0] + percent[0] + c + esc + nul + hexc + multi;
}

int (*get_handler(int kind))(const char *, ...) {
    static int (*table[])(const char *, ...) = { printf, NULL };
    return table[kind & 1];
}

void control(int argc, char **argv) {
    register int i;
    for (i = 0; i < argc; i++) {
        switch (argv[i][0]) {
        case '-':
            if (argv[i][1] == '-') continue;
            break;
        case '\\':
            goto done;
        default:
            while (0) {}
            do { i++; } while (i < 0);
        }
    }
done:
    return;
}

int main(int argc, char *argv[]) {
    volatile restrict int *p = NULL;
    struct node n = { .value = MAX(1, 2), .next = NULL, .u.word = 0 };
    bool ok = true || false;
    size_t len = sizeof n / sizeof(struct node);
    LONG_MACRO(n.value);
    control(argc, argv);
    printf("%s %zu %d\n", PLATFORM, len, ok);
    return strings() ? EXIT_SUCCESS : EXIT_FAILURE;
}

// KNOWN GAP: a string continued with a backslash-newline; the string context
// pops at end of line, so the second line lexes as code
const char *continued = "first half \
second half";

/* C++ bits, since .cpp/.hpp share this grammar */
// KNOWN GAP: C++ raw strings R"(...)" are lexed as a normal string
const char *raw = R"(no \n escapes "here")";
template <typename T> class Box { public: T value; };
int after_cpp = 0;
