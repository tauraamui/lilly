#include <stdio.h>
#include <string.h>

void computeLPSArray(const char *pattern, int patternLength, int *lps) {
    int length = 0; // length of the previous longest prefix suffix
    lps[0] = 0;     // lps[0] is always 0
    int i = 1;

    while (i < patternLength) {
        if (pattern[i] == pattern[length]) {
            length++;
            lps[i] = length;
            i++;
        } else {
            if (length != 0) {
                length = lps[length - 1];
            } else {
                lps[i] = 0;
                i++;
            }
        }
    }
}

void KMPSearch(const char *text, const char *pattern) {
    int textLength = strlen(text);
    int patternLength = strlen(pattern);
    int lps[patternLength]; // Preallocated memory for LPS array

    computeLPSArray(pattern, patternLength, lps);

    int i = 0; // index for text
    int j = 0; // index for pattern
    while (i < textLength) {
        if (pattern[j] == text[i]) {
            i++;
            j++;
        }

        if (j == patternLength) {
            printf("Pattern found at index %d\n", i - j);
            j = lps[j - 1];
        } else if (i < textLength && pattern[j] != text[i]) {
            if (j != 0) {
                j = lps[j - 1];
            } else {
                i++;
            }
        }
    }
}

int main() {
    const char *text = "ABABDABACDABABCABAB";
    const char *pattern = "ABABCABAB";
    KMPSearch(text, pattern);
    return 0;
}
