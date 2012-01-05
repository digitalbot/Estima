//
//  AudioDeviceList.h
//  Estima
//
//  Created by kosuke nakamura on 12/01/03.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import "Utils.h"


/* notification */
extern NSString *AudioDeviceListDidConnectedNewDeviceNotification;
extern NSString *AudioDeviceListDidDisconnectedDeveceNotification;

/* prototype */
OSStatus deviceConfigurationChangeListener(AudioDeviceID,
                                           unsigned int,
                                           const AudioObjectPropertyAddress inAddresses[],
                                           void *);
OSStatus deviceErrorListener(AudioDeviceID,
                             unsigned int,
                             const AudioObjectPropertyAddress inAddresses[],
                             void *);


@interface AudioDeviceList : NSObject {
    NSMutableArray *_inputDeviceList;
    NSMutableArray *_outputDeviceList;
    unsigned int _inputDeviceCount;
    unsigned int _outputDeviceCount;
}

@property(strong, readonly) NSArray *inputDeviceList;
@property(strong, readonly) NSArray *outputDeviceList;
@property(readonly) unsigned int inputDeviceCount;
@property(readonly) unsigned int outputDeviceCount;

- (void)dumpDeviceNames;
- (void)dumpCurrentDevices;

@end

