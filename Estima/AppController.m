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
@synthesize closeFpButton = _closeFpbutton;
@synthesize countLabel = _countLabel;
@synthesize xLabel     = _xLabel;
@synthesize yLabel     = _yLabel;
@synthesize zLabel     = _zLabel;
@synthesize PlaneWindow = _PlaneWindow;
@synthesize xyView      = _xyView;
@synthesize yzView      = _yzView;
@synthesize xzView      = _xzView;
@synthesize planeCount = _planeCount;
@synthesize planeX     = _planeX;
@synthesize planeY     = _planeY;
@synthesize planeZ     = _planeZ;


#pragma mark - init

- (void)awakeFromNib {
    NSLog(@"awaked");
    _audioInputBuf = [[AudioInputBuffer alloc] initWithBufferSizeTime:(kIntervalTime)];
    _calculator    = [[EstimaCalculator alloc] init];
    
    [_audioInputBuf setDelegate:_calculator];
    [_calculator setDelegate:self];
    _mainQueue = dispatch_get_main_queue();
    _fp = fopen("/Users/kosuke/Desktop/results.txt", "w");
}

- (void)dealloc {
    fclose(_fp);
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

- (IBAction)closeFp:(id)sender {
    if ([sender state] == NSOnState) {
        fclose(_fp);
    }
}

#pragma mark - EstimaCalculator delegate method

- (void)didCalculated:(EstimaCalculator *)calculator
          withAnswers:(stAnswers)answers
             countNum:(unsigned int)num {

    NSLog(@"<%d>did calculated!", num);
    [_resultView setResult:answers.x :answers.y :answers.z :num];
    [_xyView setResult:answers.x :answers.y :answers.z :num];
    [_yzView setResult:answers.x :answers.y :answers.z :num];
    [_xzView setResult:answers.x :answers.y :answers.z :num];
    dispatch_async(_mainQueue, ^{
        if (_firstTime == nil) {
            NSLog(@"first !");
            _firstTime = [NSDate date];
        }
        NSTimeInterval since  = - [_firstTime timeIntervalSinceNow];
        fprintf(_fp, "%f %f %f %f\n", since, answers.x, answers.y, answers.z);
        [_countLabel setStringValue:[NSString stringWithFormat:@"count: %d", num]];
        [_xLabel setStringValue:[NSString stringWithFormat:@"X: %f", answers.x]];
        [_yLabel setStringValue:[NSString stringWithFormat:@"Y: %f", answers.y]];
        [_zLabel setStringValue:[NSString stringWithFormat:@"Z: %f", answers.z]];
        
        [_planeCount setStringValue:[NSString stringWithFormat:@"count: %d", num]];
        [_planeX setStringValue:[NSString stringWithFormat:@"X: %f", answers.x]];
        [_planeY setStringValue:[NSString stringWithFormat:@"Y: %f", answers.y]];
        [_planeZ setStringValue:[NSString stringWithFormat:@"Z: %f", answers.z]];
        NSLog(@"<%d>ALL DANE IN MAIN QUEUE: %f", num, since);
    });
    
    return;
}

@end
