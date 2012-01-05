//
//  AudioDevice.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/02.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "AudioDevice.h"


/* notification */
NSString *AudioDeviceDidChangeSampleRateNotification = @"sample rate";


@interface AudioDevice (private)
- (void)countChannel;
- (void)cleanUp;
@end


@implementation AudioDevice

#pragma mark - property

@synthesize deviceID         = _deviceID;
@synthesize isInput          = _isInput;
@synthesize safetyOffset     = _safetyOffset;
@synthesize deviceLatency    = _deviceLatency;
@synthesize numberOfChannels = _numberOfChannels;
@synthesize sampleRate       = _sampleRate;
@synthesize format           = _format;
@synthesize name             = _name;

- (unsigned int)bufferSizeFrames {
    return _bufferSizeFrames;
}

- (void)setBufferSize:(unsigned int)size {
    unsigned int propsize = sizeof(unsigned int);
    AudioObjectPropertyAddress address;

    if (_isInput == YES) {
        address.mScope = kAudioDevicePropertyScopeInput;
    }
    else {
        address.mScope = kAudioDevicePropertyScopeOutput;
    }
    address.mSelector = kAudioDevicePropertyBufferFrameSize;
    address.mElement  = kAudioObjectPropertyElementMaster;

    AudioObjectSetPropertyData(_deviceID, &address, 0, NULL, propsize, &size);

    AudioObjectGetPropertyData(_deviceID, &address, 0, NULL, &propsize, &_bufferSizeFrames);
}

- (BOOL)isValid {
    BOOL result = NO;
    unsigned int isValid;
    unsigned int propsize = sizeof(unsigned int);

    AudioObjectPropertyAddress address;

    address.mScope    = kAudioObjectPropertyScopeGlobal;
    address.mSelector = kAudioDevicePropertyDeviceIsAlive;
    address.mElement  = kAudioObjectPropertyElementMaster;

    AudioObjectGetPropertyData(_deviceID, &address, 0, NULL, &propsize, &isValid);
    result = (BOOL)isValid;
    return result;
}


#pragma mark - initialize methods

- (id)initWithID:(AudioDeviceID)deviceID isInput:(BOOL)isInput {
    self = [super init];

    if (self) {
        OSStatus err = noErr;
        unsigned int propsize = sizeof(unsigned int);

        _deviceID = deviceID;
        _isInput  = isInput;
        if (_deviceID == kAudioDeviceUnknown) {
            NSLog(@"[ERROR]: unknown.");
            return nil;
        }
        AudioObjectPropertyAddress address;
        address.mElement = kAudioObjectPropertyElementMaster;

        // get device name
        char deviceName[64];
        unsigned int maxlen = sizeof(deviceName);
        address.mSelector = kAudioDevicePropertyDeviceName;
        address.mScope    = kAudioObjectPropertyScopeGlobal;
        AudioObjectGetPropertyData(_deviceID, &address, 0, NULL, &maxlen, deviceName);
        _name = [NSString stringWithCString:deviceName encoding:NSUTF8StringEncoding];

        if (_isInput == YES) {
            address.mScope = kAudioDevicePropertyScopeInput;
        }
        else {
            address.mScope = kAudioDevicePropertyScopeOutput;
        }
        // get safety offset
        propsize = sizeof(unsigned int);
        address.mSelector = kAudioDevicePropertySafetyOffset;
        err = AudioObjectGetPropertyData(_deviceID, &address, 0, NULL, &propsize, &_safetyOffset);
        if (err) {
            NSLog(@"[ERROR]: Safety offset error %@.", _name);
            return nil;
        }
        // get latency
        propsize = sizeof(unsigned int);
        address.mSelector = kAudioDevicePropertyLatency;
        err = AudioObjectGetPropertyData(_deviceID, &address, 0, NULL, &propsize, &_deviceLatency);
        if (err) {
            NSLog(@"[ERROR]: Latency error %@.", _name);
            return nil;
        }
        // get buffer size
        propsize = sizeof(unsigned int);
        address.mSelector = kAudioDevicePropertyBufferFrameSize;
        err = AudioObjectGetPropertyData(_deviceID, &address, 0, NULL, &propsize, &_bufferSizeFrames);
        if (err) {
            NSLog(@"[ERROR]: Buffer size error %@.", _name);
            return nil;
        }
        // get sampling rate
        propsize = sizeof(double);
        address.mSelector = kAudioDevicePropertyNominalSampleRate;
        err = AudioObjectGetPropertyData(_deviceID, &address, 0, NULL, &propsize, &_sampleRate);
        if (err) {
            NSLog(@"[ERROR]: Sample rate error %@.", _name);
            return nil;
        }

        /* notification */
        AudioObjectAddPropertyListener(_deviceID,
                                       &address,
                                       deviceSampleRateChangeListener,
                                       (__bridge void*)self);

        // get number of channels
        [self countChannel];

        if (err) {
            NSLog(@"[ERROR]: Device error %@.", _name);
            return nil;
        }
        NSLog(@"AudioDevice initWithID DONE.");
    }
    return self;
}

- (id)initWithCurrentDevice:(BOOL)isInput {
    AudioDeviceID currentDevice;
    AudioObjectPropertyAddress address;
    unsigned int size = sizeof(AudioDeviceID);

    if (isInput == YES) {
        address.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    }
    else {
        address.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
    }

    address.mScope   = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, &currentDevice);

    self = [self initWithID:currentDevice isInput:isInput];
    NSLog(@"AudioDevice initWithCurrentDevice DONE.");
    return self;
}

- (void)dealloc {
    [self cleanUp];
}


#pragma mark - AudioDevice

+ (AudioDeviceID)currentDeviceID:(BOOL)isInput {
    AudioDeviceID currentDeviceID;
    AudioObjectPropertyAddress address;
    unsigned int size =  sizeof(AudioDeviceID);

    if (isInput == YES) {
        address.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    }
    else {
        address.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
    }

    address.mScope   = kAudioObjectPropertyScopeGlobal;
    address.mElement = kAudioObjectPropertyElementMaster;
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, &currentDeviceID);

    return currentDeviceID;
}


#pragma mark - listener proc

OSStatus deviceSampleRateChangeListener(AudioObjectID inObjectID,
                                        unsigned int inNumberAddresses,
                                        const AudioObjectPropertyAddress inAddresses[],
                                        void *inClientData) {
    OSStatus err = noErr;
    @autoreleasepool {
        AudioDevice *device = (__bridge AudioDevice *)inClientData;

        if ([device isValid]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:AudioDeviceDidChangeSampleRateNotification
                                                  object:nil];
        }
    }
    return err;
}

@end


#pragma mark - private

@implementation AudioDevice (private)

- (void)countChannel {
    OSStatus err;
    unsigned int propsize;
    unsigned int result = 0;

    AudioObjectPropertyAddress address;

    if (_isInput == YES) {
        address.mScope = kAudioDevicePropertyScopeInput;
    }
    else {
        address.mScope = kAudioDevicePropertyScopeOutput;
    }

    address.mSelector = kAudioDevicePropertyStreamConfiguration;
    address.mElement  = kAudioObjectPropertyElementMaster;

    AudioObjectGetPropertyDataSize(_deviceID, &address, 0, NULL, &propsize);

    AudioBufferList *buflist = (AudioBufferList *)malloc(propsize);
    if (buflist == NULL) {
        NSLog(@"[FATAL]: Out of memory.");
        return;
    }
    err = AudioObjectGetPropertyData(_deviceID, &address, 0, NULL, &propsize, buflist);

    if (!err) {
        for (int i=0; i<buflist->mNumberBuffers; i++) {
            result += buflist->mBuffers[i].mNumberChannels;
        }
    }
    free(buflist);
    _numberOfChannels = result;
}

- (void)cleanUp {
    AudioObjectPropertyAddress address;

    address.mScope = (_isInput == YES) ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput;
    address.mElement = kAudioObjectPropertyElementMaster;

    /* sample rate */
    address.mSelector = kAudioDevicePropertyNominalSampleRate;
    AudioObjectRemovePropertyListener(_deviceID,
                                      &address,
                                      deviceSampleRateChangeListener,
                                      (__bridge void *)self);
}

@end
