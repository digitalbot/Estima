//
//  Utils.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/05.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "Utils.h"

#pragma mark - utility

// use MEM_CALLOC macro
void *memCallocFunc(char *filename, int line, size_t n, size_t size) {
    void *p;
    p = calloc(n, size);
    if (p == NULL) {
        NSLog(@"[FATAL]: Out of memory! at<%s>, line:%d", filename, line);
        exit(-1);
    }
    return p;
}
// use MEM_REALLOC macro
void *memReallocFunc(char *filename, int line, void *ptr, size_t size) {
    void *checker;
    checker = realloc(ptr, size);
    if (checker == NULL) {
        NSLog(@"[FATAL]: Out of memory! at<%s>, line:%d", filename, line);
        exit(-1);
    }
    return checker;
}


unsigned int NextPowerOfTwo(unsigned int value) {
    unsigned int  result = 1;
    while (result < value) {
        result <<= 1;
    }
    return result;
}

unsigned int PreviousPowerOfTwo(unsigned int value) {
    unsigned int  result = 1;
    value >>= 1;
    while (result < value) {
        result <<= 1;
    }
    return result;
}

@implementation Utils

@end
