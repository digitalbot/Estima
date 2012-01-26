//
//  AudioInputBuffer.h
//  Estima
//
//  Created by kosuke nakamura on 12/01/02.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioUnitIO.h"
#import "Utils.h"

@protocol AudioInputBufferDelegate;
@class RingBuffer, AudioDeviceList;

@interface AudioInputBuffer : NSObject <AudioUnitIOAudioInputDelegate> {
    __weak id<AudioInputBufferDelegate> _delegate;

    AudioUnitIO     *_audioUnitIO;
    RingBuffer      *_ringBuffer;
    AudioDeviceList *_deviceList;

    float  _bufferSizeTime;
    double _firstInputTime;
    
    dispatch_queue_t _inputQueue;
    
    float **_buffers;
    unsigned int _numberOfFrames;
    unsigned int _countNumber;

}

@property(weak) id<AudioInputBufferDelegate> delegate;
@property(strong, readonly) AudioUnitIO *audioUnitIO;
@property(readonly) float bufferSizeTime;

- (id)initWithBufferSizeTime:(float)bufferSizeTime;

@end


@protocol AudioInputBufferDelegate <NSObject>
@required
- (void)inputBufferDidFilledBuffer:(AudioBufferList *)bufferList
                withNumberOfFrames:(unsigned int)numOfFrames
                       countNumber:(unsigned int)num;
@end
