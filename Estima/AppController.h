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
#import "XYPlaneOpenGLView.h"
#import "YZPlaneOpenGLView.h"
#import "XZPlaneOpenGLView.h"
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
    __weak NSButton           *_closeFpButton;

    __weak NSTextField        *_countLabel;
    __weak NSTextField        *_xLabel;
    __weak NSTextField        *_yLabel;
    __weak NSTextField        *_zLabel;
    
    __unsafe_unretained NSPanel *_Planewindow;
    __weak XYPlaneOpenGLView    *_xyView;
    __weak YZPlaneOpenGLView    *_yzView;
    __weak XZPlaneOpenGLView    *_xzView;
    
    __weak NSTextField          *_planeCount;
    __weak NSTextField          *_planeX;
    __weak NSTextField          *_planeY;
    __weak NSTextField          *_planeZ;
    
    dispatch_queue_t _mainQueue;
    FILE *_fp;
    
    NSDate *_firstTime;

}

@property(weak) IBOutlet ResultOpenGLView *resultView;
@property(weak) IBOutlet NSButton         *startButton;
@property(weak) IBOutlet NSButton         *monitorButton;
@property(weak) IBOutlet NSButton         *closeFpButton;
@property(weak) IBOutlet NSTextField *countLabel;
@property(weak) IBOutlet NSTextField *xLabel;
@property(weak) IBOutlet NSTextField *yLabel;
@property(weak) IBOutlet NSTextField *zLabel;

@property(unsafe_unretained) IBOutlet NSPanel *PlaneWindow;
@property(weak) IBOutlet XYPlaneOpenGLView *xyView;
@property(weak) IBOutlet YZPlaneOpenGLView *yzView;
@property(weak) IBOutlet XZPlaneOpenGLView *xzView;
@property(weak) IBOutlet NSTextField *planeCount;
@property(weak) IBOutlet NSTextField *planeX;
@property(weak) IBOutlet NSTextField *planeY;
@property(weak) IBOutlet NSTextField *planeZ;


- (IBAction)startAndStop:(id)sender;
- (IBAction)monitoringStartAndStop:(id)sender;
- (IBAction)closeFp:(id)sender;
@end
