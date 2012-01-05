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


// utility c functions
void *memCallocFunc(char *filename, int line, size_t n, size_t size);

UInt32 NextPowerOfTwo(UInt32 value);


@interface Utils : NSObject

@end
