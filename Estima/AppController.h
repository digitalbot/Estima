//
//  AppController.h
//  Estima
//
//  Created by kosuke nakamura on 12/01/02.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AudioInputBuffer.h"
#import "ResultOpenGLView.h"
#import "EstimaCalculator.h"
#import "Utils.h"

#define kIntervalTime 0.2

@interface AppController : NSObject <NSWindowDelegate, EstimaCalculatorDelegate> {
    AudioInputBuffer *_audioInputBuf;
    EstimaCalculator *_calculator;

    /* outlet */
    __weak ResultOpenGLView   *_resultView;
    __weak NSButton           *_startButton;
    __weak NSButton           *_monitorButton;

}

@property(weak) IBOutlet ResultOpenGLView *resultView;
@property(weak) IBOutlet NSButton         *startButton;
@property(weak) IBOutlet NSButton         *monitorButton;


- (IBAction)startAndStop:(id)sender;
- (IBAction)monitoringStartAndStop:(id)sender;

@end
