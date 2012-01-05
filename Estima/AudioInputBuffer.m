//
//  AudioInputBuffer.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/02.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "AudioInputBuffer.h"
#import "AudioUnitIO.h"
#import "RingBuffer.h"
#import "AudioDevice.h"
#import "AudioDeviceList.h"


@implementation AudioInputBuffer

@synthesize delegate       = _delegate;
@synthesize audioUnitIO    = _audioUnitIO;
@synthesize bufferSizeTime = _bufferSizeTime;


#pragma mark - init

- (id)initWithBufferSizeTime:(float)bufferSizeTime {
    self = [super init];
    if (self) {
        _audioUnitIO = [[AudioUnitIO alloc] init];
        _audioUnitIO.delegate = self;

        _firstInputTime = -1;
        _bufferSizeTime = bufferSizeTime;
        
        _ringBuffer = [[RingBuffer alloc] initWithNumberOfChannels:_audioUnitIO.recordFormat.mChannelsPerFrame
                                                         frameSize:_audioUnitIO.recordFormat.mBytesPerFrame
                                                    capacityFrames:(_audioUnitIO.recordFormat.mSampleRate
                                                                    * _bufferSizeTime)];

        _inputQueue = dispatch_queue_create("AudioInputBuffer", NULL);
   
        /* notification */
        _deviceList = [[AudioDeviceList alloc] init];

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self
                   selector:@selector(deviceDidDisconnected:)
                       name:AudioDeviceListDidDisconnectedDeveceNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(newDeviceDidConnected:)
                       name:AudioDeviceListDidConnectedNewDeviceNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(deviceSampleRateDidChange:)
                       name:AudioDeviceDidChangeSampleRateNotification
                     object:nil];
        NSLog(@"AudioInputBuffer initWithBufferSizeTime DONE.");
    }
    return self;
}

- (void)dealloc {
    dispatch_release(_inputQueue);
}


#pragma mark - AudioInputBuffer

- (void)resetAudioInput {
    [_audioUnitIO stopRunning];
    [_audioUnitIO cleanUp];
    _audioUnitIO = nil;
    _audioUnitIO = [[AudioUnitIO alloc] init];
    _audioUnitIO.delegate = self;
    _firstInputTime = -1;
}


#pragma mark -notification

- (void)deviceDidDisconnected:(NSNotification *)notification {
    [self resetAudioInput];
}

- (void)newDeviceDidConnected:(NSNotification *)notification {
    [self resetAudioInput];
}

- (void)deviceSampleRateDidChange:(NSNotification *)notification {
    [self resetAudioInput];
}


#pragma mark - delegate

- (void)inputUnitDidFilledBuffer:(AudioBufferList *)bufferList
                      sampleTime:(double)sampleTime
                     numOfFrames:(unsigned int)numOfFrames {

    double requireBufferSizeFrames;
    OSStatus err = noErr;

    if (_firstInputTime == -1) {
        _firstInputTime = sampleTime;
    }

    [_ringBuffer storeInBuffer:bufferList
                    sampleTime:sampleTime
                   numOfFrames:numOfFrames];

    /* if filled */
    requireBufferSizeFrames = _audioUnitIO.recordFormat.mSampleRate * _bufferSizeTime;
    if ((sampleTime - _firstInputTime + numOfFrames) >= requireBufferSizeFrames) {
        AudioBufferList *bufferList;
        bufferList = createAudioBufferList(_audioUnitIO.recordFormat.mChannelsPerFrame,
                                           requireBufferSizeFrames * _audioUnitIO.recordFormat.mBytesPerFrame);

        err = [_ringBuffer fetchFromBuffer:bufferList
                              inSampleTime:_firstInputTime
                               numOfFrames:requireBufferSizeFrames];
        _firstInputTime = - 1;//+= requireBufferSizeFrames;
        
        if (err) {
            NSLog(@"[ERROR]: fetch error.");
            return;
        }
    
        dispatch_async(_inputQueue, ^{
            [_delegate inputBufferDidFilledBuffer:bufferList
                                      numOfFrames:requireBufferSizeFrames];
            removeAudioBufferList(bufferList);
        });
    }
}

@end
