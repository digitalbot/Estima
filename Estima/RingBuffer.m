//
//  RingBuffer.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/03.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "RingBuffer.h"

@interface RingBuffer (private)
- (void)setTimeBoundsInStartTime:(SampleTime)startTime endTime:(SampleTime)endTime;
- (RingBufferError)checkTimeBoundsInStartTime:(SampleTime)startRead endTime:(SampleTime)endRead;
- (int)frameOffsetInSampleTime:(SampleTime)frameNumber;
- (void)fillZeroInBuffers:(char **)buffers
        withNumOfChannels:(short)numOfChannels
                   offset:(int)offset
                   length:(int)nbytes;

- (void)storeABLInBuffers:(char **)buffers
            withBufOffset:(int)bufOffset
                   srcABL:(AudioBufferList *)abl
                srcOffset:(int)srcOffset
                   length:(int)nbytes;

- (void)storeBuffersInABL:(AudioBufferList *)abl
           withDataOffset:(int)destOffset
                  buffers:(char **)buffers
                bufOffset:(int)bufOffset
                   length:(int)nbytes;
@end


#pragma mark - public

@implementation RingBuffer


#pragma mark - property

@dynamic startTime;
- (SampleTime)startTime {
    return _timeBoundsQueue[_timeBoundsQueuePtr & kTimeBoundsQueueMask].mStartTime;
}
@dynamic endTime;
- (SampleTime)endTime {
    return _timeBoundsQueue[_timeBoundsQueuePtr & kTimeBoundsQueueMask].mEndTime;
}


#pragma mark - initialize methods

- (id)initWithNumberOfChannels:(short)numOfChannels
                     frameSize:(int)bytesPerFrame
                capacityFrames:(unsigned int)capacityFrames {

    self = [super init];
    if (self) {
        capacityFrames = NextPowerOfTwo(capacityFrames);

        _numberOfChannels   = numOfChannels;
        _bytesPerFrame      = bytesPerFrame;
        _capacityFrames     = capacityFrames;
        _capacityFramesMask = capacityFrames - 1;
        _capacityBytes      = bytesPerFrame * capacityFrames;

        char *p = (char *)malloc(_numberOfChannels * (_capacityBytes + sizeof(char *))); //free?
        _datas = (char **)p;
        p += _numberOfChannels * sizeof(char *);
        for (int i=0; i<_numberOfChannels; i++) {
            _datas[i] = p;
            p += _capacityBytes;
        }
        for (int i=0; i<kTimeBoundsQueueSize; i++) {
            _timeBoundsQueue[i].mStartTime     = 0;
            _timeBoundsQueue[i].mEndTime       = 0;
            _timeBoundsQueue[i].mUpdateCounter = 0;
        }
        _timeBoundsQueuePtr = 0;
    }
    return self;
}

- (void)dealloc {
    if (_datas || (_datas == NULL)) {
        free(_datas);
        _datas = nil;
    }
}


#pragma mark - store and fetch

- (RingBufferError)storeInBuffer:(AudioBufferList *)abl
                      sampleTime:(SampleTime)startWrite
                     numOfFrames:(unsigned int)framesToWrite {

    if (framesToWrite > _capacityFrames) {
        NSLog(@"[ERROR]: Too much data.");
        return kRingBufferError_TooMuch;
    }

    SampleTime endWrite = startWrite + framesToWrite;

    if (startWrite < self.endTime) {
        [self setTimeBoundsInStartTime:startWrite endTime:startWrite];
    }
    else if (endWrite - self.startTime <= _capacityFrames) {
    }
    else {
        SampleTime newStart = endWrite - _capacityFrames;
        SampleTime newEnd;

        newEnd = (newStart < self.endTime) ? self.endTime : newStart;
        [self setTimeBoundsInStartTime:newStart endTime:newEnd];
    }

    /* write new frame */
    char **buffers = _datas;
    int nChannels = _numberOfChannels;
    int offset0, offset1, nbytes;
    SampleTime curEnd = self.endTime;

    if (startWrite > curEnd) {
        offset0 = [self frameOffsetInSampleTime:curEnd];
        offset1 = [self frameOffsetInSampleTime:startWrite];
        if (offset0 < offset1) {
            [self fillZeroInBuffers:buffers
                  withNumOfChannels:nChannels
                             offset:offset0
                             length:(offset1 - offset0)];
        }
        else {
            [self fillZeroInBuffers:buffers
                  withNumOfChannels:nChannels
                             offset:offset0
                             length:(_capacityBytes - offset0)];
            [self fillZeroInBuffers:buffers
                  withNumOfChannels:nChannels
                             offset:0
                             length:offset1];
        }
        offset0 = offset1;
    }
    else {
        offset0 = [self frameOffsetInSampleTime:startWrite];
    }

    offset1 = [self frameOffsetInSampleTime:endWrite];
    if (offset0 < offset1) {
        [self storeABLInBuffers:buffers
                  withBufOffset:offset0
                         srcABL:abl
                      srcOffset:0
                         length:(offset1 - offset0)];
    }
    else {
        nbytes = _capacityBytes - offset0;
        [self storeABLInBuffers:buffers
                  withBufOffset:offset0
                         srcABL:abl
                      srcOffset:0
                         length:nbytes];
        [self storeABLInBuffers:buffers
                  withBufOffset:0
                         srcABL:abl
                      srcOffset:nbytes
                         length:offset1];
    }

    /* now update the end time */
    [self setTimeBoundsInStartTime:self.startTime endTime:endWrite];
    return kRingBufferError_OK;
}

- (RingBufferError)fetchFromBuffer:(AudioBufferList *)abl
                      inSampleTime:(SampleTime)startRead
                       numOfFrames:(unsigned int)framesToRead {

    SampleTime endRead = startRead + framesToRead;
    RingBufferError err;

    err = [self checkTimeBoundsInStartTime:startRead endTime:endRead];
    if (err) {
        NSLog(@"[ERROR]: checkTimeBoundsInStartTime is failed.");
        return err;
    }

    char **buffers = _datas;
    int offset0 = [self frameOffsetInSampleTime:startRead];
    int offset1 = [self frameOffsetInSampleTime:endRead];

    if (offset0 < offset1) {
        [self storeBuffersInABL:abl
                 withDataOffset:0
                        buffers:buffers
                      bufOffset:offset0
                         length:(offset1 - offset0)];
    }
    else {
        int nbytes = _capacityBytes - offset0;
        [self storeBuffersInABL:abl
                 withDataOffset:0
                        buffers:buffers
                      bufOffset:offset0
                         length:nbytes];
        [self storeBuffersInABL:abl
                 withDataOffset:nbytes
                        buffers:buffers
                      bufOffset:0
                         length:offset1];
    }
    return [self checkTimeBoundsInStartTime:startRead endTime:endRead];
}


#pragma mark - getter

- (RingBufferError)timeBoundsInStartTime:(SampleTime *)startTime endTime:(SampleTime *)endTime {
    for (int i=0; i<8; i++) {
        unsigned int curPtr = _timeBoundsQueuePtr;
        unsigned int index  = curPtr & kTimeBoundsQueueMask;
        sTimeBounds *bounds = _timeBoundsQueue + index;

        *startTime = bounds->mStartTime;
        *endTime   = bounds->mEndTime;
        unsigned int newPtr = bounds->mUpdateCounter;

        if (newPtr == curPtr) {
            return kRingBufferError_OK;
        }
    }
    NSLog(@"[ERROR]: CPU overloaded.");
    return kRingBufferError_CPUOverload;
}


#pragma mark - dump methods

- (void)dumpData {
    float **show = (float **)_datas;
    for (int i=0; i<_numberOfChannels; i++) {
        for (int j=0; j<(_capacityBytes/sizeof(float)); j++) {
            printf("%d %f\n", j, show[i][j]);
        }
    }
}

@end


#pragma mark - private

@implementation RingBuffer (private)

- (void)setTimeBoundsInStartTime:(SampleTime)startTime endTime:(SampleTime)endTime {
    unsigned int nextPtr = _timeBoundsQueuePtr + 1;
    unsigned int index   = nextPtr & (kTimeBoundsQueueMask);

    _timeBoundsQueue[index].mStartTime     = startTime;
    _timeBoundsQueue[index].mEndTime       = endTime;
    _timeBoundsQueue[index].mUpdateCounter = nextPtr;

    CompareAndSwap(_timeBoundsQueuePtr, _timeBoundsQueuePtr + 1, &_timeBoundsQueuePtr);
}

- (RingBufferError)checkTimeBoundsInStartTime:(SampleTime)startRead endTime:(SampleTime)endRead {
    SampleTime startTime, endTime;

    RingBufferError err = [self timeBoundsInStartTime:&startTime endTime:&endTime];

    if (err) {
        NSLog(@"[ERROR]: Getting error.");
        return err;
    }

    if (startRead < startTime) {
        if (endRead > endTime) {
            NSLog(@"[ERROR]: Too much.");
            printf("startRead: %ld | startTime: %ld\n", startRead, startTime);
            printf("endRead:   %ld | endTime:   %ld\n", endRead, endTime);
            return kRingBufferError_TooMuch;
        }
        if (endRead < startTime) {
            NSLog(@"[ERROR]: Way behind.");
            printf("startRead: %ld | startTime: %ld\n", startRead, startTime);
            printf("endRead:   %ld | endTime:   %ld\n", endRead, endTime);
            return kRingBufferError_WayBehind;
        }
        else {
            NSLog(@"[ERROR]: Slightly behind.");
            printf("startRead: %ld | startTime: %ld\n", startRead, startTime);
            printf("endRead:   %ld | endTime:   %ld\n", endRead, endTime);
            return kRingBufferError_SlightlyBehind;
        }
    }
    if (endRead > endTime) {
        if (startRead > endTime) {
            NSLog(@"[ERROR]: Way ahead.");
            printf("startRead: %ld | startTime: %ld\n", startRead, startTime);
            printf("endRead:   %ld | endTime:   %ld\n", endRead, endTime);
            return kRingBufferError_WayAhead;
        }
        else {
            NSLog(@"[ERROR]: Slightly ahead.");
            printf("startRead: %ld | startTime: %ld\n", startRead, startTime);
            printf("endRead:   %ld | endTime:   %ld\n", endRead, endTime);
            return kRingBufferError_SlightlyAhead;
        }
    }
    return kRingBufferError_OK;
}

/* change SampleTime to list index */
- (int)frameOffsetInSampleTime:(SampleTime)frameNumber {
    return (frameNumber & _capacityFramesMask) * _bytesPerFrame;
}

/* fill 0 from list[offset] to list[nbytes] */
- (void)fillZeroInBuffers:(char **)buffers
        withNumOfChannels:(short)nChannels
                   offset:(int)offset
                   length:(int)nbytes {

    while (--nChannels >= 0) {
        memset(*buffers + offset, 0, nbytes);
        ++buffers;
    }
}

/* store abl in buffers */
- (void)storeABLInBuffers:(char **)buffers
            withBufOffset:(int)bufOffset
                   srcABL:(AudioBufferList *)abl
                srcOffset:(int)srcOffset
                   length:(int)nbytes {

    int nChannels = abl->mNumberBuffers;
    const AudioBuffer *src = abl->mBuffers;

    while (--nChannels >= 0) {
        memcpy(*buffers + bufOffset, (Byte *)src->mData + srcOffset, nbytes);
        ++buffers;
        ++src;
    }
}

/* store buffers in abl */
- (void)storeBuffersInABL:(AudioBufferList *)abl
           withDataOffset:(int)destOffset
                  buffers:(char **)buffers
                bufOffset:(int)bufOffset
                   length:(int)nbytes {

    int nChannels = abl->mNumberBuffers;
    const AudioBuffer *dest = abl->mBuffers;

    while (--nChannels >= 0) {
        memcpy((char *)dest->mData + destOffset, *buffers + bufOffset, nbytes);
        ++buffers;
        ++dest;
    }
}

@end
