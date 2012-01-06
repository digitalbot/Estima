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
@synthesize xLabel = _xLabel;
@synthesize yLabel = _yLabel;
@synthesize zLabel = _zLabel;

#pragma mark - init

- (void)awakeFromNib {
    NSLog(@"awaked");
    _audioInputBuf = [[AudioInputBuffer alloc] initWithBufferSizeTime:(kIntervalTime)];
    _calculator    = [[EstimaCalculator alloc] init];
    
    [_audioInputBuf setDelegate:_calculator];
    [_calculator setDelegate:self];
    _mainQueue = dispatch_get_main_queue();
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
    dispatch_async(_mainQueue, ^{
        [_xLabel setStringValue:[NSString stringWithFormat:@"X: %f", answers.x]];
        [_yLabel setStringValue:[NSString stringWithFormat:@"Y: %f", answers.y]];
        [_zLabel setStringValue:[NSString stringWithFormat:@"Z: %f", answers.z]];
    });
    
    return;
}

@end
