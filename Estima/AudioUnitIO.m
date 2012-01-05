//
//  AudioUnitIO.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/02.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "AudioUnitIO.h"
#import "AudioDevice.h"
#import "AudioDeviceList.h"
#import "RingBuffer.h"


@interface AudioUnitIO (private)
- (OSStatus)prepareAudioUnitWithInput:(AudioDeviceID)input output:(AudioDeviceID)output;
- (OSStatus)setupAUHAL;
- (OSStatus)enableIO;
- (OSStatus)callbackSetup;
- (OSStatus)setupGraph;
- (OSStatus)makeGraph;
- (OSStatus)setupFormatsAndBuffers;
- (void)computeThruOffset;
@end


#pragma mark - public

@implementation AudioUnitIO

@synthesize delegate            = _delegate;
@synthesize recordFormat        = _recordFormat;
@synthesize currentInput        = _currentInput;
@synthesize currentOutput       = _currentOutput;
@synthesize isRunning           = _isRunning;
@synthesize isMonitoring        = _isMonitoring;
@synthesize inputQueue          = _inputQueue;
@synthesize firstInputTime      = _firstInputTime;
@synthesize firstOutputTime     = _firstOutputTime;
@synthesize inToOutSampleOffset = _inToOutSampleOffset;
@synthesize ringBuffer          = _ringBuffer;
@synthesize inputBuffer         = _inputBuffer;
@synthesize inputUnit           = _inputUnit;
@synthesize varispeedUnit       = _varispeedUnit;

- (unsigned int)bufferSize {
    return (unsigned int)kAudioUnitIODeviceBufferSize;
}


#pragma mark - init and dealloc

- (id)init {
    return [self initWithInput:kAudioDeviceUnknown output:kAudioDeviceUnknown];
}

- (id)initWithInput:(AudioDeviceID)input output:(AudioDeviceID)output {
    self = [super init];
    if (self) {
        OSStatus err = noErr;
        _ioLock = [[NSLock alloc] init];

        /* setup */
        err = [self prepareAudioUnitWithInput:input output:output];
        if (err) {
            NSLog(@"[ERROR]: AudioUnitIO initialize error.");
            return nil;
        }
        /* create queue */
        _inputQueue = dispatch_queue_create("AudioUnitIO", NULL);
        NSLog(@"AudioUnitIO initWithInput DONE.");
    }
    return self;
}

- (void)cleanUp {
    [self stopRunning];
    
    removeAudioBufferList(_inputBuffer);
    AudioUnitUninitialize(_inputUnit);
    AUGraphClose(_graph);
    DisposeAUGraph(_graph);
    
    dispatch_release(_inputQueue);
}

- (void)dealloc {
    [self cleanUp];
}


#pragma mark - start and stop

- (OSStatus)startRunning {
    [_ioLock lock];
    OSStatus err = noErr;
    if (!_isRunning) {
        /* start input */
        err = AudioOutputUnitStart(_inputUnit);
        if (err) {
            NSLog(@"[ERROR]: AudioUnitIO AudioOutputUnitStart() error.");
            return err;
        }
        err = AUGraphStart(_graph);
        if (err) {
            NSLog(@"[ERROR]: AudioUnitIO AUGraphStart() error.");
            return err;
        }

        _firstInputTime  = -1;
        _firstOutputTime = -1;
        _isRunning = YES;
        NSLog(@"IO START");
    }
    [_ioLock unlock];
    return err;
}

- (OSStatus)stopRunning {
    OSStatus err = noErr;
    if (_isRunning) {
        /* stop input */
        err = AudioOutputUnitStop(_inputUnit);
        if (err) {
            NSLog(@"[ERROR]: AudioUnitIO AudioOutputUnitStop() error.");
            return err;
        }
        err = AUGraphStop(_graph);
        if (err) {
            NSLog(@"[ERROR]: AudioUnitIO AUGraphStop() error.");
            return err;
        }
        _isRunning = NO;
        NSLog(@"IO STOP");
    }
    return err;
}


#pragma mark - setting

- (OSStatus)setOutputDeviceAsCurrent:(AudioDeviceID)output {
    OSStatus err = noErr;

    /* get default output device */
    if (output == kAudioDeviceUnknown) {
        output = [AudioDevice currentDeviceID:NO];
    }

    /* set output device specified device */
    err = AudioUnitSetProperty(_outputUnit,
                               kAudioOutputUnitProperty_CurrentDevice,
                               kAudioUnitScope_Global,
                               0,
                               &output,
                               sizeof(output));
    if (err) {
        NSLog(@"[ERROR]: AudioUnitIO output device set to output unit error.");
        return err;
    }

    /* store in instance with bufSize */
    _currentOutput = [[AudioDevice alloc] initWithID:output isInput:NO];
    [_currentOutput setBufferSize:kAudioUnitIODeviceBufferSize];

    NSLog(@"output: %@, id: %d", _currentOutput.name, _currentOutput.deviceID);
    return err;
}

- (OSStatus)setInputDeviceAsCurrent:(AudioDeviceID)input {
    OSStatus err = noErr;

    /* get default input device */
    if (input == kAudioDeviceUnknown) {
        input = [AudioDevice currentDeviceID:YES];
    }

    /* set input device current device */
    err = AudioUnitSetProperty(_inputUnit,
                               kAudioOutputUnitProperty_CurrentDevice,
                               kAudioUnitScope_Global,
                               0,
                               &input,
                               sizeof(input));
    if (err) {
        NSLog(@"[ERROR]: AudioUnitIO input device set to input unit error.");
        return err;
    }

    /* store in instance with bufSize */
    _currentInput = [[AudioDevice alloc] initWithID:input isInput:YES];
    [_currentInput setBufferSize:kAudioUnitIODeviceBufferSize];

    NSLog(@"input: %@", _currentInput.name);
    return err;
}


#pragma mark - C func

static OSStatus inputProc(void *inRefCon,
                          AudioUnitRenderActionFlags *ioActionFlags,
                          const AudioTimeStamp *inTimeStamp,
                          unsigned int inBusNumber,
                          unsigned int inNumberFrames,
                          AudioBufferList *ioData) {

    OSStatus err = noErr;
    @autoreleasepool {
        AudioUnitIO *playThru = (__bridge AudioUnitIO *)inRefCon;

        if (playThru.isRunning) {
            if (playThru.firstInputTime < 0.0) {
                playThru.firstInputTime = inTimeStamp->mSampleTime;
            }
        }

        err = AudioUnitRender(playThru.inputUnit,
                              ioActionFlags,
                              inTimeStamp,
                              inBusNumber,
                              inNumberFrames,
                              playThru.inputBuffer);
        /* save to ring buffer */
        if (!err) {
            [playThru.ringBuffer storeInBuffer:playThru.inputBuffer
                                    sampleTime:(SampleTime)inTimeStamp->mSampleTime
                                   numOfFrames:(double)inNumberFrames];
        }

        /* call GCD from delegate */
        if (playThru.delegate) {
            AudioBufferList *copyBufList = 0;
            copyAudioBufferList(playThru.inputBuffer, &copyBufList);

            dispatch_async(playThru.inputQueue, ^{
                if ([playThru.delegate respondsToSelector:@selector
                     (inputUnitDidFilledBuffer:sampleTime:numOfFrames:)]) {
                    [playThru.delegate inputUnitDidFilledBuffer:copyBufList
                                                     sampleTime:inTimeStamp->mSampleTime
                                                    numOfFrames:inNumberFrames];
                    removeAudioBufferList(copyBufList);
                }
            });
        }
    }
    return err;
}

static OSStatus outputProc(void *inRefCon,
                           AudioUnitRenderActionFlags *ioActionFlags,
                           const AudioTimeStamp *inTimeStamp,
                           unsigned int inBusNumber,
                           unsigned int inNumberFrames,
                           AudioBufferList *ioData) {

    OSStatus err = noErr;
    @autoreleasepool {
        AudioUnitIO *playThru = (__bridge AudioUnitIO *)inRefCon;

        double rate = 0.0;
        AudioTimeStamp inTS, outTS;

        if (playThru.firstInputTime < 0.0 || playThru.isMonitoring == NO) {
            makeBufferSilent(ioData);
            return noErr;
        }

        /*
         * サンプルレートの違いによる微妙なズレをオフセットするためにvarispeedのプレイバックレートを使う
         * インプット、アウトプットデバイスのレートスケーラを取得
         * レートスケーラとはホスト側の実際のチックと名目的なチックの比率である
         */
        err = AudioDeviceGetCurrentTime(playThru.currentInput.deviceID, &inTS);
        if (err) {
            makeBufferSilent(ioData);
            return noErr;
        }

        AudioDeviceGetCurrentTime(playThru.currentOutput.deviceID, &outTS);

        rate = inTS.mRateScalar / outTS.mRateScalar;
        AudioUnitSetParameter(playThru.varispeedUnit,
                              kVarispeedParam_PlaybackRate,
                              kAudioUnitScope_Global,
                              0,
                              rate,
                              0);

        /* add to offset */
        if (playThru.firstOutputTime < 0.0) {
            playThru.firstOutputTime = inTimeStamp->mSampleTime;
            double delta = (playThru.firstOutputTime - playThru.firstInputTime);
            [playThru computeThruOffset];

            if (delta < 0.0) {
                playThru.inToOutSampleOffset -= delta;
            }
            else {
                playThru.inToOutSampleOffset += delta;
            }
            makeBufferSilent(ioData);
            return noErr;
        }

        double offset = playThru.inToOutSampleOffset;

        /* get from ringbuffer */
        err = [playThru.ringBuffer fetchFromBuffer:ioData
                                      inSampleTime:((SampleTime)inTimeStamp->mSampleTime - offset)
                                       numOfFrames:inNumberFrames];

        if (err != kRingBufferError_OK) {
            makeBufferSilent(ioData);
            SampleTime bufferStartTime, bufferEndTime;
            [playThru.ringBuffer timeBoundsInStartTime:&bufferStartTime
                                               endTime:&bufferEndTime];
            playThru.inToOutSampleOffset = inTimeStamp->mSampleTime - bufferStartTime;
        }
    }
    return noErr;
}

@end


#pragma mark - private

@implementation AudioUnitIO (private)

- (OSStatus)prepareAudioUnitWithInput:(AudioDeviceID)input output:(AudioDeviceID)output {
    OSStatus err = noErr;

    err = [self setupAUHAL];
    if (err) {
        NSLog(@"[ERROR]: setupAUHAL is failed.");
        return err;
    }
    err = [self setupGraph];
    if (err) {
        NSLog(@"[ERROR]: setupGraph is failed.");
        return err;
    }
    err = [self setInputDeviceAsCurrent:input];
    if (err) {
        NSLog(@"[ERROR]: setInputDeviceAsCurrent is failed.");
        return err;
    }
    err = [self setOutputDeviceAsCurrent:output];
    if (err) {
        NSLog(@"[ERROR]: setOutputDeviceAsCurrent is failed.");
        return err;
    }
    err = [self callbackSetup];
    if (err) {
        NSLog(@"[ERROR]: callbacksetup is failed.");
        return err;
    }
    err = [self setupFormatsAndBuffers];
    if (err) {
        NSLog(@"[ERROR]: setupFormatsAndBuffers is failed.");
        return err;
    }
    
    err = AUGraphConnectNodeInput(_graph, _varispeedNode, 0, _outputNode, 0);
    if (err) {
        NSLog(@"[ERROR]: AUGraphConnectNodeInput is failed.");
        return err;
    }
    err = AUGraphInitialize(_graph);
    if (err) {
        NSLog(@"[ERROR]: AUGraphInitialize is failed.");
        return err;
    }
    
    [self computeThruOffset];

    return err;
}

- (OSStatus)setupAUHAL {
    OSStatus err = noErr;

    /* generate unit */
    AudioComponentDescription desc;
    desc.componentType         = kAudioUnitType_Output;
    desc.componentSubType      = kAudioUnitSubType_HALOutput;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    desc.componentFlags        = 0;
    desc.componentFlagsMask    = 0;

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (comp == NULL) {
        NSLog(@"[FATAL]: couldn't setup component.");
        exit(-1);
    }

    AudioComponentInstanceNew(comp, &_inputUnit);

    /* setup and initialize */
    err = [self enableIO];
    err = AudioUnitInitialize(_inputUnit);

    return err;
}

- (OSStatus)enableIO {
    OSStatus err = noErr;
    unsigned int enableIO = 1;
    err = AudioUnitSetProperty(_inputUnit,
                               kAudioOutputUnitProperty_EnableIO,
                               kAudioUnitScope_Input,
                               1,
                               &enableIO,
                               sizeof(enableIO));
    enableIO = 0;
    err = AudioUnitSetProperty(_inputUnit,
                               kAudioOutputUnitProperty_EnableIO,
                               kAudioUnitScope_Output,
                               0,
                               &enableIO,
                               sizeof(enableIO));
    return err;
}

- (OSStatus)setupGraph {
    OSStatus err = noErr;

    err = NewAUGraph(&_graph);
    err = AUGraphOpen(_graph);
    err = [self makeGraph];

    unsigned int startAtZero = 0;
    err = AudioUnitSetProperty(_outputUnit,
                               kAudioOutputUnitProperty_StartTimestampsAtZero,
                               kAudioUnitScope_Global,
                               0,
                               &startAtZero,
                               sizeof(startAtZero));
    return err;
}

- (OSStatus)makeGraph {
    OSStatus err = noErr;
    AudioComponentDescription varispeedDesc, outDesc;

    /* make node. varispeedUnit is cushion */
    varispeedDesc.componentType         = kAudioUnitType_FormatConverter;
    varispeedDesc.componentSubType      = kAudioUnitSubType_Varispeed;
    varispeedDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    varispeedDesc.componentFlags        = 0;
    varispeedDesc.componentFlagsMask    = 0;

    outDesc.componentType               = kAudioUnitType_Output;
    outDesc.componentSubType            = kAudioUnitSubType_DefaultOutput;
    outDesc.componentManufacturer       = kAudioUnitManufacturer_Apple;
    outDesc.componentFlags              = 0;
    outDesc.componentFlagsMask          = 0;

    err = AUGraphAddNode(_graph, &varispeedDesc, &_varispeedNode);
    err = AUGraphAddNode(_graph, &outDesc, &_outputNode);

    /* create audio unit */
    err = AUGraphNodeInfo(_graph, _varispeedNode, NULL, &_varispeedUnit);
    err = AUGraphNodeInfo(_graph, _outputNode, NULL, &_outputUnit);

    return err;
}

- (OSStatus)callbackSetup {
    OSStatus err = noErr;
    AURenderCallbackStruct inputStruct, outputStruct;

    /* setup input callback */
    inputStruct.inputProc = inputProc;
    (inputStruct.inputProcRefCon) = (__bridge void *)self;

    err = AudioUnitSetProperty(_inputUnit,
                               kAudioOutputUnitProperty_SetInputCallback,
                               kAudioUnitScope_Global,
                               0,
                               &inputStruct,
                               sizeof(inputStruct));

    /* setup output callback */
    outputStruct.inputProc = outputProc;
    outputStruct.inputProcRefCon = (__bridge void *)self;
    AUGraphSetNodeInputCallback(_graph,
                                _varispeedNode,
                                0,
                                &outputStruct);
    return err;
}

- (OSStatus)setupFormatsAndBuffers {
    OSStatus err = noErr;
    unsigned int bufferSizeFrames;

    AudioStreamBasicDescription asbd, asbd_dev1_in, asbd_dev2_out;
    double rate = 0;

    /* get inputunit bufSize */
    unsigned int propertySize = sizeof(bufferSizeFrames);
    err = AudioUnitGetProperty(_inputUnit,
                               kAudioDevicePropertyBufferFrameSize,
                               kAudioUnitScope_Global,
                               0,
                               &bufferSizeFrames,
                               &propertySize);

    /* get input format to inputunit */
    propertySize = sizeof(asbd_dev1_in);
    err = AudioUnitGetProperty(_inputUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input,
                               1,
                               &asbd_dev1_in,
                               &propertySize);

    /* get output format from inputunit */
    propertySize = sizeof(asbd);
    err = AudioUnitGetProperty(_inputUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Output,
                               1,
                               &asbd,
                               &propertySize);

    unsigned int bufferSizeBytes = bufferSizeFrames * asbd.mBytesPerFrame;
    NSLog(@"buffersize: %d byte.", bufferSizeBytes);

    /* get output format from outputunit */
    propertySize = sizeof(asbd_dev2_out);
    err = AudioUnitGetProperty(_outputUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Output,
                               0,
                               &asbd_dev2_out,
                               &propertySize);

    /* set sampling rate */
    asbd.mSampleRate = (double)(kInputDataSampleRate);
    asbd.mChannelsPerFrame = asbd_dev1_in.mChannelsPerFrame;

    /* copy format from inputdata, permit access */
    _recordFormat = asbd;
    printf("------ Record Format ------\n");
    printStreamDesc(&_recordFormat);
    printf("---------------------------\n");

    /* set asbd (output of inputunit and input of varispeedunit) */
    propertySize = sizeof(asbd);
    err = AudioUnitSetProperty(_inputUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Output,
                               1,
                               &asbd,
                               propertySize);
    err = AudioUnitSetProperty(_varispeedUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input,
                               0,
                               &asbd,
                               propertySize);

    /* get samplerate of output device */
    AudioObjectPropertyAddress address;

    address.mSelector = kAudioDevicePropertyNominalSampleRate;
    address.mScope    = kAudioObjectPropertyScopeGlobal;
    address.mElement  = kAudioObjectPropertyElementMaster;

    propertySize = sizeof(double);
    err = AudioObjectGetPropertyData(_currentOutput.deviceID,
                                     &address,
                                     0,
                                     NULL,
                                     &propertySize,
                                     &rate);
    asbd.mSampleRate = rate;
    propertySize = sizeof(asbd);

    /* set format of output device (output of varispeedunit and input of outputunit) */
    err = AudioUnitSetProperty(_varispeedUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Output,
                               0,
                               &asbd,
                               propertySize);
    err = AudioUnitSetProperty(_outputUnit,
                               kAudioUnitProperty_StreamFormat,
                               kAudioUnitScope_Input,
                               0,
                               &asbd,
                               propertySize);

    /* ensure inputbuffer */
    _inputBuffer = createAudioBufferList(asbd.mChannelsPerFrame, bufferSizeBytes);

    /* prepare ringbuffer */
    _ringBuffer = [[RingBuffer alloc] initWithNumberOfChannels:asbd.mChannelsPerFrame
                                                     frameSize:asbd.mBytesPerFrame
                                                capacityFrames:(bufferSizeFrames * 20)];

    return err;
}

- (void)computeThruOffset {
    _inToOutSampleOffset = (int)(_currentInput.safetyOffset
                                 + _currentInput.bufferSizeFrames
                                 + _currentOutput.safetyOffset
                                 + _currentOutput.bufferSizeFrames);
}

@end


#pragma mark - c func

AudioBufferList *createAudioBufferList(unsigned short numOfChannels,
                                       unsigned int bufferByteSize) {

    AudioBufferList *resultList = NULL;

    /* ensure buffer */
    unsigned int propsize;
    propsize = offsetof(AudioBufferList, mBuffers[0]) + (sizeof(AudioBuffer) * numOfChannels);
    resultList = (AudioBufferList *)MEM_CALLOC(1, propsize);
    resultList->mNumberBuffers = numOfChannels;

    for (int i=0; i<numOfChannels; i++) {
        resultList->mBuffers[i].mNumberChannels = 1;
        resultList->mBuffers[i].mDataByteSize = bufferByteSize;
        resultList->mBuffers[i].mData = MEM_CALLOC(1, bufferByteSize);
    }
    return resultList;
}

void removeAudioBufferList(AudioBufferList *bufList) {
    if (bufList) {
        for (int i=0; i<bufList->mNumberBuffers; i++) {
            free(bufList->mBuffers[i].mData);
        }
        free(bufList);
        bufList = nil;
    }
}

void copyAudioBufferList(AudioBufferList *fromBufList, AudioBufferList **toBufList) {
    *toBufList = createAudioBufferList(fromBufList->mNumberBuffers,
                                       fromBufList->mBuffers[0].mDataByteSize);

    for (int i=0; i<fromBufList->mNumberBuffers; i++) {
        (*toBufList)->mBuffers[i].mNumberChannels = fromBufList->mBuffers[i].mNumberChannels;
        (*toBufList)->mBuffers[i].mDataByteSize   = fromBufList->mBuffers[i].mDataByteSize;
        memmove((*toBufList)->mBuffers[i].mData,
                fromBufList->mBuffers[i].mData,
                fromBufList->mBuffers[i].mDataByteSize);
    }
}

void makeBufferSilent(AudioBufferList *ioData) {
    for (int i=0; i<ioData->mNumberBuffers; i++) {
        for (int j=0; j<ioData->mBuffers[i].mDataByteSize; j++) {
            Byte *array = (Byte *)ioData->mBuffers[i].mData;
            array[j] = 0;
        }
    }
}

void printStreamDesc(AudioStreamBasicDescription *inDesc) {
    if (!inDesc) {
        NSLog(@"[ERROR]: Couldn't print a NULL description.'");
        return;
    }

	printf ("Sample Rate      :%f\n", inDesc->mSampleRate);
	printf ("Format ID        :%s\n", (char *)&inDesc->mFormatID);
	printf ("Format Flags     :%u\n", inDesc->mFormatFlags);
	printf ("BytesPerPacket   :%u\n", inDesc->mBytesPerPacket);
	printf ("FramesPerPacket  :%u\n", inDesc->mFramesPerPacket);
	printf ("BytesPerFrame    :%u\n", inDesc->mBytesPerFrame);
	printf ("ChannelsPerFrame :%u\n", inDesc->mChannelsPerFrame);
	printf ("Bits per Channel :%u\n", inDesc->mBitsPerChannel);
}
