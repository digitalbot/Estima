//
//  Utils.h
//  Estima
//
//  Created by kosuke nakamura on 12/01/05.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import <Foundation/Foundation.h>


#define	MEM_CALLOC(n, size)   \
(memCallocFunc(__FILE__, __LINE__, n, size))
#define	MEM_REALLOC(ptr, size)   \
(memReallocFunc(__FILE__, __LINE__, (void *)ptr, size))


// utility c functions
void *memCallocFunc(char *filename, int line, size_t n, size_t size);
void *memReallocFunc(char *filename, int line, void *ptr, size_t size);

unsigned int NextPowerOfTwo(unsigned int value);
unsigned int PreviousPowerOfTwo(unsigned int value);

@interface Utils : NSObject

@end
