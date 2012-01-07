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

#define kPowerNumberOfTwo 0.0 // 2の肩の数
#define kMicDist       5.0
#define kSonic         33899.30921
#define kSamplePer     kInputDataSampleRate
#define kLimitTime     ((kMicDist) / (kSonic))
#define kUpedPerSample (1.0 / (kSamplePer * pow(2.0, kPowerNumberOfTwo)))
#define kLimitSample   ((int)((kLimitTime / kUpedPerSample)))
#define kOffset        (1000)
#define kRange         (60000 + kOffset)

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
    unsigned int _count;
}

@property(weak)     id<EstimaCalculatorDelegate> delegate;
@property           BOOL                         isCaluculating;
@property(readonly) unsigned int                 baseNumberOfSamples;
@property(readonly) unsigned int                 responseNumberOfSamples;

- (void)calculateWithABL:(AudioBufferList *)bufferList;

- (void)interpolateWithData:(float *)baseData
               responseData:(float *)resData;

- (void)calcCCFWithData:(double *)baseData
                subData:(double *)subData
                 result:(sCCFResult *)result
                   name:(NSString *)name;

- (void)estimate:(sAnswers *)ans;

- (void)dumpCCFResult:(sCCFResult *)result withName:(NSString *)name;

@end

@protocol EstimaCalculatorDelegate <NSObject>
@required
- (void)didCalculated:(EstimaCalculator *)calculator
          withAnswers:(sAnswers)answers
             countNum:(unsigned int)num;
@end

