//
//  AppController.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/02.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "AppController.h"


@implementation AppController

@synthesize resultView    = _resultView;
@synthesize startButton   = _startButton;
@synthesize monitorButton = _monitorButton;

#pragma mark - init

- (void)awakeFromNib {
    NSLog(@"awaked");
    _audioInputBuf = [[AudioInputBuffer alloc] initWithBufferSizeTime:(kIntervalTime)];
    _calculator    = [[EstimaCalculator alloc] init];
    
    [_audioInputBuf setDelegate:_calculator];
    [_calculator setDelegate:self];
}

#pragma mark - IBAction

- (IBAction)startAndStop:(id)sender {
    if ([sender state] == NSOffState) {
        if (_audioInputBuf.audioUnitIO.isRunning) {
            if (_monitorButton.state == NSOffState) {
                [_audioInputBuf.audioUnitIO stopRunning];
            }
        }
        _calculator.isCaluculating = NO;
    }
    else {
        if (!_audioInputBuf.audioUnitIO.isRunning) {
            [_audioInputBuf.audioUnitIO startRunning];
        }
        _calculator.isCaluculating = YES;
    }
}

- (IBAction)monitoringStartAndStop:(id)sender {
    if ([sender state] == NSOffState) {
        if (_audioInputBuf.audioUnitIO.isMonitoring) {
           _audioInputBuf.audioUnitIO.isMonitoring = NO;
            if (_startButton.state == NSOffState) {
                [_audioInputBuf.audioUnitIO stopRunning];
            }
        }
    }
    else {
        if (!_audioInputBuf.audioUnitIO.isRunning) {
            [_audioInputBuf.audioUnitIO startRunning];
        }
        _audioInputBuf.audioUnitIO.isMonitoring = YES;
    }
}

#pragma mark - EstimaCalculator delegate method

- (void)didCalculated:(EstimaCalculator *)calculator
          withAnswers:(sAnswers)answers {

    NSLog(@"did calculated!");
    [_resultView setResult:answers.x :answers.y :answers.z];
    return;
}

@end
