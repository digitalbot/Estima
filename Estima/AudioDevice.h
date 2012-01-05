//
//  AudioDevice.h
//  Estima
//
//  Created by kosuke nakamura on 12/01/02.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AVFoundation/AVFoundation.h>


/* notification */
extern NSString *AudioDeviceDidChangeSampleRateNotification;

/* prototype */
OSStatus deviceSampleRateChangeListener(AudioObjectID,
                                        unsigned int,
                                        const AudioObjectPropertyAddress inAddresses[],
                                        void *);


@interface AudioDevice : NSObject {
    AudioDeviceID               _deviceID;
    BOOL                        _isInput;
    unsigned int                _safetyOffset;
    unsigned int                _deviceLatency;
    unsigned int                _bufferSizeFrames;
    unsigned short              _numberOfChannels;
    double                      _sampleRate;
    AudioStreamBasicDescription _format;
    NSString                    *_name;
    AVCaptureDevice             *_captureDevice;
}

@property(readonly) AudioDeviceID               deviceID;
@property(readonly) BOOL                        isInput;
@property(readonly) unsigned int                safetyOffset;
@property(readonly) unsigned int                deviceLatency;
@property(setter=setBufferSize:) unsigned int   bufferSizeFrames;
@property(readonly) unsigned short              numberOfChannels;
@property(readonly) double                      sampleRate;
@property(readonly) AudioStreamBasicDescription format;
@property(readonly, copy) NSString              *name;
@property(readonly) BOOL                        isValid;


+ (AudioDeviceID)currentDeviceID:(BOOL)isInput;
- (id)initWithID:(AudioDeviceID)deviceID isInput:(BOOL)isInput;
- (id)initWithCurrentDevice:(BOOL)isInput;

@end

