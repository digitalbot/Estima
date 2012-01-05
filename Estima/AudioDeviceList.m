//
//  AudioDeviceList.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/03.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "AudioDeviceList.h"
#import "AudioDevice.h"

/* notification */
NSString *AudioDeviceListDidConnectedNewDeviceNotification = @"connect";
NSString *AudioDeviceListDidDisconnectedDeveceNotification = @"disconect";

@interface AudioDeviceList (private)
- (void)loadCurrentDevices;
- (void)cleanUp;
@end


@implementation AudioDeviceList

@synthesize inputDeviceCount  = _inputDeviceCount;
@synthesize outputDeviceCount = _outputDeviceCount;
@synthesize inputDeviceList   = _inputDeviceList;
@synthesize outputDeviceList  = _outputDeviceList;


#pragma mark - init and dealloc

- (id)init {
    self = [super init];
    if (self) {
        [self loadCurrentDevices];

        /* add listener */
        AudioObjectPropertyAddress address;
        address.mSelector = kAudioHardwarePropertyDevices;
        address.mScope    = kAudioObjectPropertyScopeGlobal;
        address.mElement  = kAudioObjectPropertyElementMaster;

        AudioObjectAddPropertyListener(kAudioObjectSystemObject,
                                       &address,
                                       deviceConfigurationChangeListener,
                                       (__bridge void *)self);

        address.mSelector = kAudioHardwareBadDeviceError;
        AudioObjectAddPropertyListener(kAudioObjectSystemObject,
                                       &address,
                                       deviceErrorListener,
                                       (__bridge void *)self);
        NSLog(@"AudioDeviceList init DONE.");
    }
    return self;
}

- (void)dealloc {
    [self cleanUp];
}


#pragma mark - dump methods

- (void)dumpDeviceNames {
    AudioDevice *device;
    NSString *string;

    for (int i=0; i<[_inputDeviceList count]; i++) {
        device = [_inputDeviceList objectAtIndex:i];
        string = [NSString stringWithString:device.name];
        NSLog(@"---INPUT---");
        NSLog(@"%d: %@", i, string);
    }
    for (int i=0; i<[_outputDeviceList count]; i++) {
        device = [_outputDeviceList objectAtIndex:i];
        string = [NSString stringWithString:device.name];
        NSLog(@"---OUTPUT---");
        NSLog(@"%d: %@", i, string);
    }
}

- (void)dumpCurrentDevices {
    AudioDeviceID inputDevice;
    AudioDeviceID outputDevice;
    unsigned int  size;

    AudioObjectPropertyAddress address;
    address.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    address.mScope    = kAudioObjectPropertyScopeGlobal;
    address.mElement  = kAudioObjectPropertyElementMaster;

    size = sizeof(inputDevice);
    AudioObjectGetPropertyData(kAudioObjectSystemObject,
                               &address,
                               0,
                               NULL,
                               &size,
                               &inputDevice);

    address.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
    size = sizeof(outputDevice);
    AudioObjectGetPropertyData(kAudioObjectSystemObject,
                               &address,
                               0,
                               NULL,
                               &size,
                               &outputDevice);

    AudioDevice *input = [[AudioDevice alloc] initWithID:inputDevice isInput:YES];
    AudioDevice *output = [[AudioDevice alloc] initWithID:outputDevice isInput:NO];

    NSString *inputDeviceName = [NSString stringWithString:input.name];
    NSString *outputDeviceName = [NSString stringWithString:output.name];

    NSLog(@"current input: %@", inputDeviceName);
    NSLog(@"current output: %@", outputDeviceName);
}


#pragma mark - listener proc

OSStatus deviceConfigurationChangeListener(AudioDeviceID inObjectID,
                                           unsigned int inNumberAddresses,
                                           const AudioObjectPropertyAddress inAddresses[],
                                           void *inClientData) {

    OSStatus err = noErr;
    @autoreleasepool {
        AudioDeviceList *audioDeviceList;
        NSArray *priviousInputDevices, *priviousOutputDevices;

        audioDeviceList = (__bridge AudioDeviceList *)inClientData;
        priviousInputDevices = [audioDeviceList.inputDeviceList copy];
        priviousOutputDevices = [audioDeviceList.outputDeviceList copy];
        [audioDeviceList loadCurrentDevices];

        NSInteger priviousDeviceCount = [priviousInputDevices count] + [priviousOutputDevices count];
        NSInteger newDeviceCount = [audioDeviceList.inputDeviceList count] + [audioDeviceList.outputDeviceList count];

        if (priviousDeviceCount < newDeviceCount) {
            [[NSNotificationCenter defaultCenter] postNotificationName:AudioDeviceListDidConnectedNewDeviceNotification
                                                  object:(__bridge id)inClientData];
        }
        else if (priviousDeviceCount > newDeviceCount) {
            if ([audioDeviceList.inputDeviceList count] != 0 || [audioDeviceList.outputDeviceList count] != 0) {
                [[NSNotificationCenter defaultCenter] postNotificationName:AudioDeviceListDidDisconnectedDeveceNotification
                                                      object:(__bridge id)inClientData];
            }
        }
    }
    return err;
}

OSStatus deviceErrorListener(AudioDeviceID inObjectID,
                             unsigned int inNumberAddresses,
                             const AudioObjectPropertyAddress inAddresses[],
                             void *inClientData) {

    OSStatus err = noErr;
    @autoreleasepool {
        NSLog(@"[ERROR]: DEVICE ERROR.");
    }
    return err;
}

@end


#pragma mark - private

@implementation AudioDeviceList (private)

- (void)loadCurrentDevices {
    NSLog(@"LOAD");
    OSStatus err = noErr;
    AudioObjectPropertyAddress address;
    address.mSelector = kAudioHardwarePropertyDevices;
    address.mScope    = kAudioObjectPropertyScopeGlobal;
    address.mElement  =  kAudioObjectPropertyElementMaster;

    unsigned int propsize;
    err = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,
                                         &address,
                                         0,
                                         NULL,
                                         &propsize);
    if (err) {
        NSLog(@"[ERROR]: Cannot get device info");
    }
    //verify_noerr(AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &propsize, NULL));

    /* get number of device */
    unsigned int count = propsize / sizeof(AudioDeviceID);

    /* get all devices info */
    AudioDeviceID *devids = (AudioDeviceID *)MEM_CALLOC(1, propsize);
    err = AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                     &address,
                                     0,
                                     NULL,
                                     &propsize,
                                     devids);
    if (err) {
        NSLog(@"[ERROR]: Cannot get all devices info");
    }
    //verify_noerr(AudioHardwareGetPropertyInfo(kAudioHardwarePropertyDevices, &propsize, devids));

    _inputDeviceCount = 0;
    _inputDeviceList  = [[NSMutableArray alloc] initWithCapacity:count];

    for (int i=0; i<count; ++i) {
        AudioDevice *device = [[AudioDevice alloc] initWithID:devids[i] isInput:YES];

        if (device.numberOfChannels > 0) {
            device = [[AudioDevice alloc] initWithID:devids[i] isInput:YES];
            [_inputDeviceList addObject:device];
            _inputDeviceCount++;
        }
    }

    _outputDeviceCount = 0;
    _outputDeviceList = [[NSMutableArray alloc] initWithCapacity:count];

    for (int i=0; i<count; ++i) {
        AudioDevice *device = [[AudioDevice alloc] initWithID:devids[i] isInput:NO];

        if (device.numberOfChannels > 0) {
            device = [[AudioDevice alloc] initWithID:devids[i] isInput:NO];
            [_outputDeviceList addObject:device];
            _outputDeviceCount++;
        }
    }
    free(devids);
}

- (void)cleanUp {
    AudioObjectPropertyAddress address;

    address.mElement  = kAudioObjectPropertyElementMaster;
    address.mScope    = kAudioObjectPropertyScopeGlobal;
    address.mSelector = kAudioHardwarePropertyDevices;
    AudioObjectRemovePropertyListener(kAudioObjectSystemObject,
                                      &address,
                                      deviceConfigurationChangeListener,
                                      (__bridge void*)self);
}

@end
