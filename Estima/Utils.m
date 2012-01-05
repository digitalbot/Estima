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
    }
    return p;
}

UInt32 NextPowerOfTwo(UInt32 value) {
    UInt32 result = 1;
    while (result < value) {
        result <<= 1;
    }
    return result;
}

@implementation Utils

@end
