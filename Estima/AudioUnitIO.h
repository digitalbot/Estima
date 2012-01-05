//
//  AudioUnitIO.h
//  Estima
//
//  Created by kosuke nakamura on 12/01/02.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolBox/AudioToolBox.h>
#import <AudioUnit/AudioUnit.h>
#import "Utils.h"

/* MACRO */
#define kAudioUnitIODeviceBufferSize 128.0
#define kInputDataSampleRate         96000.0


/* C prototype */
AudioBufferList *createAudioBufferList(unsigned short numOfChannels, unsigned int bufferByteSize);
void removeAudioBufferList(AudioBufferList *bufList);
void copyAudioBufferList(AudioBufferList *fromBufList, AudioBufferList **toBufList);
void makeBufferSilent(AudioBufferList *ioData);
void printStreamDesc(AudioStreamBasicDescription *inDesc);


@class AudioDevice, AudioDeviceList, RingBuffer;
@protocol AudioUnitIOAudioInputDelegate;


#pragma mark - interface

@interface AudioUnitIO : NSObject {
    __weak id<AudioUnitIOAudioInputDelegate> _delegate;

    AudioBufferList *_inputBuffer;
    RingBuffer      *_ringBuffer;

    AudioDevice *_currentInput;
    AudioDevice *_currentOutput;

    AudioUnit _inputUnit;
    AudioUnit _outputUnit;
    AudioUnit _varispeedUnit;
    AUGraph   _graph;
    AUNode    _varispeedNode;
    AUNode    _outputNode;

    double    _firstInputTime;
    double    _firstOutputTime;
    double    _inToOutSampleOffset;

    dispatch_queue_t _inputQueue;
    AudioStreamBasicDescription _recordFormat;

    BOOL _isRunning;
    BOOL _isMonitoring;

    NSLock *_ioLock;
}

@property(weak) id<AudioUnitIOAudioInputDelegate> delegate;
@property(readonly) AudioStreamBasicDescription recordFormat;
@property(strong) AudioDevice *currentInput;
@property(strong) AudioDevice *currentOutput;
@property(readonly) unsigned int bufferSize;

@property BOOL isRunning;
@property BOOL isMonitoring;
//
@property dispatch_queue_t inputQueue;
@property double firstInputTime;
@property double firstOutputTime;
@property double inToOutSampleOffset;
@property(strong) RingBuffer *ringBuffer;
@property AudioBufferList *inputBuffer;
@property AudioUnit inputUnit;
@property AudioUnit varispeedUnit;
//

/* init */
- (id)initWithInput:(AudioDeviceID)input output:(AudioDeviceID)output;

/* start and stop */
- (OSStatus)startRunning;
- (OSStatus)stopRunning;

/* device setting */
- (OSStatus)setOutputDeviceAsCurrent:(AudioDeviceID)output;
- (OSStatus)setInputDeviceAsCurrent:(AudioDeviceID)input;

/* clean */
- (void)cleanUp;
@end


#pragma mark - delegate

@protocol AudioUnitIOAudioInputDelegate <NSObject>

@required
- (void)inputUnitDidFilledBuffer:(AudioBufferList *)bufferList
                      sampleTime:(double)sampleTime
                     numOfFrames:(unsigned int)numOfFrames;
@end
