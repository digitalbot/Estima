//
//  RingBuffer.h
//  Estima
//
//  Created by kosuke nakamura on 12/01/03.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>
#import <CoreAudio/CoreAudio.h>
#import "Utils.h"


#define kTimeBoundsQueueSize 32
#define kTimeBoundsQueueMask ((kTimeBoundsQueueSize) - 1)

typedef int RingBufferError;
typedef long SampleTime;
typedef struct {
    volatile SampleTime   mStartTime;
    volatile SampleTime   mEndTime;
    volatile unsigned int mUpdateCounter;
} sTimeBounds;

enum {
	kRingBufferError_WayBehind      = -2, // 格納されているバッファより前を指定
	kRingBufferError_SlightlyBehind = -1, // バッファより少しだけ前を指定
	kRingBufferError_OK             = 0,  // ＯＫ
	kRingBufferError_SlightlyAhead  = 1,  // バッファより少しだけ後ろを指定
	kRingBufferError_WayAhead       = 2,  // バッファより後ろを指定
	kRingBufferError_TooMuch        = 3,  // バッファ容量を超えて指定
    kRingBufferError_CPUOverload    = 4   // CPUオーバーロード
};


@interface RingBuffer : NSObject {
    char         **_datas;
    short        _numberOfChannels;
    unsigned int _bytesPerFrame;
    unsigned int _capacityFrames;
    unsigned int _capacityFramesMask;
    unsigned int _capacityBytes;

    sTimeBounds  _timeBoundsQueue[kTimeBoundsQueueSize];
    unsigned int _timeBoundsQueuePtr;
}

@property(readonly) SampleTime startTime;
@property(readonly) SampleTime endTime;


- (id)initWithNumberOfChannels:(short)numOfChannels
                     frameSize:(int)bytesPerFrame
                capacityFrames:(unsigned int)capacityFrames;

- (RingBufferError)storeInBuffer:(AudioBufferList *)abl
                      sampleTime:(SampleTime)startWrite
                     numOfFrames:(unsigned int)framesToWrite;

- (RingBufferError)fetchFromBuffer:(AudioBufferList *)abl
                      inSampleTime:(SampleTime)startWrite
                       numOfFrames:(unsigned int)framesToRead;

- (RingBufferError)timeBoundsInStartTime:(SampleTime *)startTime
                                 endTime:(SampleTime *)endTime;

- (void)dumpData;

@end
