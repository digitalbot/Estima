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
                                                                    * _bufferSizeTime + kAudioUnitIODeviceBufferSize)];

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
    for (int i=0; i<_audioUnitIO.recordFormat.mChannelsPerFrame; i++) {
        free(_buffers[i]);
    }
    free(_buffers);
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

}


#pragma mark - delegate

- (void)inputUnitDidFilledBuffer:(AudioBufferList *)bufferList
                      sampleTime:(double)sampleTime
                     numOfFrames:(unsigned int)numOfFrames {

    __block float *checkman;
    unsigned int nChannels = _audioUnitIO.recordFormat.mChannelsPerFrame;
    nChannels = (nChannels > 4) ? 4 : nChannels;
    
    float **temps = MEM_CALLOC(nChannels, sizeof(float *));
    for (int i=0; i<nChannels; i++) {
        temps[i] = (float *)bufferList->mBuffers[i].mData;
    }
    
    if (_firstInputTime == -1) {
        _firstInputTime = 1;
        _numberOfFrames = numOfFrames;
        _buffers = MEM_CALLOC(nChannels, sizeof(float *));
        for (int i=0; i<nChannels; i++) {
            _buffers[i] = MEM_CALLOC(_numberOfFrames, sizeof(float));
            for (int j=0; j<_numberOfFrames; j++) {
                _buffers[i][j] = temps[i][j];
            }
        }
    }
    else {
        _numberOfFrames += numOfFrames;
        unsigned int posOfStart = _numberOfFrames - numOfFrames;

        for (int i=0; i<nChannels; i++) {
            checkman = realloc(_buffers[i], _numberOfFrames * sizeof(float));
            if (checkman == NULL) {
                NSLog(@"[FATAL]: Out of memory.");
                exit(-1);
            }
            _buffers[i] = checkman;
            for (int j=posOfStart; j<_numberOfFrames; j++) {
                _buffers[i][j] = temps[i][j-posOfStart];
            }
        }
    }
    
    unsigned int requireBufferSizeFrames = _audioUnitIO.recordFormat.mSampleRate * _bufferSizeTime;
    if (_numberOfFrames >= requireBufferSizeFrames) {
        AudioBufferList *bufList;
        bufList = createAudioBufferList(_audioUnitIO.recordFormat.mChannelsPerFrame,
                                        requireBufferSizeFrames * _audioUnitIO.recordFormat.mBytesPerFrame);
        float **mDatas = MEM_CALLOC(nChannels, sizeof(float *));
        for (int i=0; i<nChannels; i++) {
            mDatas[i] = MEM_CALLOC(_numberOfFrames, sizeof(float));
            for (int j=0; j<_numberOfFrames; j++) {
                mDatas[i][j] = _buffers[i][j];
            }
            bufList->mBuffers[i].mData = mDatas[i];
        }
        /* delegate call */
        dispatch_async(_inputQueue, ^{
            [_delegate inputBufferDidFilledBuffer:bufList
                                      numOfFrames:requireBufferSizeFrames];
            removeAudioBufferList(bufList);
            free(mDatas);
        });
        
        unsigned int numOfExceeds = _numberOfFrames - requireBufferSizeFrames;
        for (int i=0; i<nChannels; i++) {
            for (int j=requireBufferSizeFrames; j<_numberOfFrames; j++) {
                _buffers[i][j-requireBufferSizeFrames] = _buffers[i][j];
            }
            checkman = realloc(_buffers[i], numOfExceeds);
            if (checkman == NULL) {
                NSLog(@"[FATAL]: Out of memory.");
                exit(-1);
            }
            _buffers[i] = checkman;
        }
        _numberOfFrames = numOfExceeds;
    }
    free(temps);
    
//     double requireBufferSizeFrames;
//     __block OSStatus err = noErr;

//     if (_firstInputTime == -1) {
//         _firstInputTime = sampleTime;
//     }

//     [_ringBuffer storeInBuffer:bufferList
//                     sampleTime:sampleTime
//                    numOfFrames:numOfFrames];

//     /* if filled */
//     requireBufferSizeFrames = _audioUnitIO.recordFormat.mSampleRate * _bufferSizeTime;
//     if ((sampleTime - _firstInputTime + numOfFrames) >= requireBufferSizeFrames) {
//         dispatch_async(_inputQueue, ^{
//             AudioBufferList *bufList;
//             bufList = createAudioBufferList(_audioUnitIO.recordFormat.mChannelsPerFrame,
//                                             requireBufferSizeFrames * _audioUnitIO.recordFormat.mBytesPerFrame);

//             err = [_ringBuffer fetchFromBuffer:bufList
//                                   inSampleTime:_firstInputTime
//                                    numOfFrames:requireBufferSizeFrames];
//             _firstInputTime /* = - 1;*/ += requireBufferSizeFrames;

//             if (err) {
//                 NSLog(@"[ERROR]: fetch error.");
//                 return;
//             }

//             [_delegate inputBufferDidFilledBuffer:bufList
//                                       numOfFrames:requireBufferSizeFrames];
//             removeAudioBufferList(bufList);
//         });
//     }

}

@end
