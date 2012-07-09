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

#define kPowerNumberOfTwo 2.0 // 2の肩の数
#define kMicDist          5.0
#define kSonic            33899.30921
#define kLimitTime        ((kMicDist) / (kSonic))
#define kSamplePer        kInputDataSampleRate
#define kPerSample        (1.0 / kSamplePer)
#define kUpedPerSample    (1.0 / (kSamplePer * pow(2.0, kPowerNumberOfTwo)))
#define kLimitSample      ((int)((kLimitTime / kPerSample) + 1.5))
#define kUpedLimitSample  ((int)(kLimitSample * pow(2.0, kPowerNumberOfTwo)))
#define kOffset           (20)
#define kRange            (66666 + kOffset)
#define kComp             (2)
// neo で3.0, 90000で0.4秒かかる
// neo で3.0, 70000で0.3秒弱かかる
// neo で3.0, 40000で0.06秒
// neo で4.0, 60000で0.1秒
//1.0, 75000, 2800 0.45



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
} stCCFResult;

typedef struct {
    double x;
    double y;
    double z;
} stAnswers;


@protocol EstimaCalculatorDelegate;

@interface EstimaCalculator : NSObject <AudioInputBufferDelegate> {

@private
    __weak id<EstimaCalculatorDelegate> _delegate;

    float *_interpolatedDataO;
    float *_interpolatedDataA;
    float *_interpolatedDataB;
    float *_interpolatedDataC;

    float *_bufferO;
    float *_bufferA;
    float *_bufferB;
    float *_bufferC;
    unsigned int _pos;

    unsigned int _numberOfFrames;

    stCCFResult _resultOtoA;
    stCCFResult _resultOtoB;
    stCCFResult _resultOtoC;

    BOOL  _isCalculating;
    BOOL  _isTest;
    dispatch_queue_t _inputQueue;
    unsigned int _count;

    //
    FFTSetupD _fftBaseSetup;
    FFTSetupD _fftSubSetup;
    FFTSetupD _fftResSetup;
    FFTSetupD _fftUsingSetup;
    FFTSetupD _fftUpedSetup;
    //

}

@property(weak)     id<EstimaCalculatorDelegate> delegate;
@property(readonly) unsigned int                 numberOfFrames;
@property           BOOL                         isCaluculating;
@property           BOOL                         isTest;
@property(nonatomic, readonly) unsigned int baseNumberOfSamples;
@property(nonatomic, readonly) unsigned int responseNumberOfSamples;
@property(nonatomic, readonly) unsigned int baseLog2n;
@property(nonatomic, readonly) unsigned int usingRange;
@property(nonatomic, readonly) unsigned int upedRange;
@property(nonatomic, readonly) unsigned int usingLog2n;
@property(nonatomic, readonly) unsigned int upedLog2n;

/* --- 1 --- */
- (void)calcWithABL:(AudioBufferList *)bufferList;
- (void)calcGreatCCFWithBaseData:(float *)baseData
                         subData:(float *)subData
                          result:(stCCFResult *)result
                            name:(NSString *)name;
/* --------- */

/* --- 2 --- */
- (void)calculateWithABL:(AudioBufferList *)bufferList;
- (void)interpolateWithData:(float *)baseData
               responseData:(float *)resData;
- (void)calcCCFWithData:(double *)baseData
                subData:(double *)subData
                 result:(stCCFResult *)result
                   name:(NSString *)name;
/* --------- */

/* --- 3 --- */
- (void)newCalcWithABL:(AudioBufferList *)bufferList;
- (void)newCCFWithBaseData:(float *)baseData
                   subData:(float *)subData
                    result:(stCCFResult *)result
                      name:(NSString *)name;
/* --------- */

/* --- 4 --- */
- (void)neoCalcWithABL:(AudioBufferList *)bufferList;
- (void)neoCCFWithBaseData:(float *)baseData
                   subData:(float *)subData
                    result:(stCCFResult *)result
                      name:(NSString *)name;
/* --------- */


- (void)estimate:(stAnswers *)ans;

- (void)dumpCCFResult:(stCCFResult *)result withName:(NSString *)name;

@end

@protocol EstimaCalculatorDelegate <NSObject>
@required
- (void)didCalculated:(EstimaCalculator *)calculator
          withAnswers:(stAnswers)answers
             countNum:(unsigned int)num;
@end

