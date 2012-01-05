//
//  EstimaCalculator.h
//  Estima
//
//  Created by kosuke nakamura on 12/01/04.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>
#import "AudioInputBuffer.h"
#import "AudioDataHandle.h"
#import "Utils.h"

#define kPowerNumberOfTwo 3 // 2の肩の数
#define kMicDist     50.0
#define kSonic       340000.0
#define kSamplePer   kInputDataSampleRate
#define kLimitTime   ((kMicDist) / (kSonic))
#define kPerSample   (1.0 / ( kSamplePer))
#define kLimitSample ((int)((kLimitTime / (1 / (kSamplePer * pow(2, kPowerNumberOfTwo))) + 1.0)))
#define kOffset      (500)
#define kRange       (8000 + kOffset)

typedef enum {
    kIsSame = 0,
    kIsAheadBase,
    kIsAheadSub,
} eArrivalStatuses;

typedef struct {
    double           max;
    int              indexOfMax;
    int              arrivalSampleLag;
    double           arrivalTimeLag;
    eArrivalStatuses arrivalStatus;
} sCCFResult;

typedef struct {
    double x;
    double y;
    double z;
} sAnswers;


@protocol EstimaCalculatorDelegate;

@interface EstimaCalculator : NSObject <AudioInputBufferDelegate> {

@private
    __weak id<EstimaCalculatorDelegate> _delegate;

    float *_interpolatedDataO;
    float *_interpolatedDataA;
    float *_interpolatedDataB;
    float *_interpolatedDataC;

    sCCFResult _resultOtoA;
    sCCFResult _resultOtoB;
    sCCFResult _resultOtoC;

    BOOL  _isCalculating;
    dispatch_queue_t _inputQueue;
}

@property(weak)     id<EstimaCalculatorDelegate> delegate;
@property           BOOL                         isCaluculating;
@property(readonly) unsigned int                 baseNumberOfSamples;
@property(readonly) unsigned int                 responseNumberOfSamples;

- (void)calculateWithABL:(AudioBufferList *)bufferList
             numOfFrames:(unsigned int)numOfFrames;

- (void)interpolateWithData:(float *)baseData
               responseData:(float *)resData;

- (void)calcCCFWithData:(double *)baseData
                subData:(double *)subData
                 result:(sCCFResult *)result;

- (void)estimate:(sAnswers *)ans;

- (void)dumpCCFResult:(sCCFResult *)result withName:(NSString *)name;

@end

@protocol EstimaCalculatorDelegate <NSObject>
@required
- (void)didCalculated:(EstimaCalculator *)calculator
          withAnswers:(sAnswers)answers;
@end

