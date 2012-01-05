//
//  EstimaCalculator.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/04.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "EstimaCalculator.h"

@implementation EstimaCalculator

@synthesize delegate       = _delegate;
@synthesize isCaluculating = _isCalculating;

@dynamic baseNumberOfSamples;
- (unsigned int)baseNumberOfSamples {
    return NextPowerOfTwo((double)kRange);
}
@dynamic responseNumberOfSamples;
- (unsigned int)responseNumberOfSamples {
    return (self.baseNumberOfSamples * pow(2, kPowerNumberOfTwo));
}


#pragma mark - initialize

- (id)init {
    self = [super init];
    if (self) {

        _interpolatedDataO = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        _interpolatedDataA = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        _interpolatedDataB = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        _interpolatedDataC = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));

        _inputQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        NSLog(@"EstimaCalculator init DONE.");
    }
    return self;
}

- (void)dealloc {
    free(_interpolatedDataO);
    free(_interpolatedDataA);
    free(_interpolatedDataB);
    free(_interpolatedDataC);
}


#pragma mark - delegate method

- (void)inputBufferDidFilledBuffer:(AudioBufferList *)bufferList
                       numOfFrames:(unsigned int)numOfFrames {

    if (_isCalculating == YES) {
        NSLog(@"BUFFER DID FILLED. START CALUCULATE!");
        // debug
        /*
        AudioDataHandle *baseData
        = [[AudioDataHandle alloc] initWithWavFile:@"/Users/kosuke/Downloads/1013_cross_base_mono.wav"];
         AudioDataHandle *subData
        = [[AudioDataHandle alloc] initWithWavFile:@"/Users/kosuke/Downloads/1013_cross_sub_mono.wav"];
        sCCFResult ccfresult;
        ccfresult.max = 0;
        double *upedBase = MEM_CALLOC(self.responseNumberOfSamples , sizeof(double));
        double *upedSub = MEM_CALLOC(self.responseNumberOfSamples , sizeof(double));
        float *toUpBaseTmp = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        float *toUpSubTmp = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        float *updB = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        float *updS = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        for (int i=0; i<self.responseNumberOfSamples; i++) {
            toUpBaseTmp[i] = (float)[baseData access:0 atIndex:i];
            toUpSubTmp[i]  = (float)[subData access:0 atIndex:i];
        }
        [self interpolateWithData:toUpBaseTmp responseData:updB];
        [self interpolateWithData:toUpSubTmp responseData:updS];
        for (int i=0; i<self.responseNumberOfSamples; i++) {
            upedBase[i] = (double)updB[i];
            upedSub[i] = (double)updS[i];
        }

        [self calcCCFWithData:upedBase subData:upedSub result:&ccfresult];
        [self dumpCCFResult:&ccfresult withName:@"test"];
        
        free(upedBase);
        free(upedSub);
        free(toUpBaseTmp);
        free(toUpSubTmp);
        free(updB);
        free(updS);
        return;
         */
        //
        [self calculateWithABL:bufferList numOfFrames:numOfFrames];
    }
    else {
        NSLog(@"calcurator is stopping.");
    }
}


#pragma mark - calculation CORE

- (void)calculateWithABL:(AudioBufferList *)bufferList
             numOfFrames:(unsigned int)numOfFrames {

    float *dataO = (float *)bufferList->mBuffers[0].mData;
    float *dataA = (float *)bufferList->mBuffers[1].mData;
    //float *dataB = (float *)bufferList->mBuffers[2].mData;
    //float *dataC = (float *)bufferList->mBuffers[3].mData;

    /* debug
    for (int i=0; i<50; i++) {
        printf("mData[0]: %.10f | mData[1]: %.10e\n", dataO[i], dataA[i]);
    }
     */
    [self interpolateWithData:dataO responseData:_interpolatedDataO];
    [self interpolateWithData:dataA responseData:_interpolatedDataA];

    unsigned int sampleRate = kInputDataSampleRate * pow(2.0, kPowerNumberOfTwo);
    unsigned int numOfSamples = self.responseNumberOfSamples;

    void **temp = [AudioDataHandle prepareInitWithDatas:kIsFloat
                                          numOfChannels:2//4
                                              firstData:_interpolatedDataO,
                   _interpolatedDataA/*, _interpolatedDataB, _interpolatedDataC*/];
    /* debug
    NSLog(@"temp");
    for (int i=0; i<50; i++) {
        printf("inted: %.10e | temp: %.10f\n", _interpolatedDataA[i], ((float **)temp)[1][i]);
    }
     */
    AudioDataHandle *audioDatas
    = [[AudioDataHandle alloc] initWithDatas:temp
                                numOfSamples:numOfSamples
                               numOfChannels:2//4
                               samplesPerSec:sampleRate
                                    dataType:kIsFloat];
    // OK
    //[audioDatas dumpDatas];
    [audioDatas dumpInfo:@"test"];
    free(temp);

    [self calcCCFWithData:[audioDatas dataWithChannel:0]
                  subData:[audioDatas dataWithChannel:1]
                   result:&_resultOtoA];
    //[self calcCCFWithData:[audioDatas dataWithChannel:0]
    //              subData:[audioDatas dataWithChannel:2]
    //               result:&_resultOtoB];
    //[self calcCCFWithData:[audioDatas dataWithChannel:0]
    //              subData:[audioDatas dataWithChannel:3]
    //               result:&_resultOtoC];
    [self dumpCCFResult:&_resultOtoA withName:@"OtoA"];
    //[self dumpCCFResult:&_resultOtoB withName:@"OtoB"];
    //[self dumpCCFResult:&_resultOtoC withName:@"OtoC"];

    /* check ccf error */
    //if ((resulfOtoA.arrivalStatus
    //     + resultOtoB.arrivalStatus
    //     + resultOtoC.arrivalStatus) < 2) {
    //    NSLog(@"[ERROR]: CalcCCF error.");
    //    return;
    //}

    dispatch_async(_inputQueue, ^{
        
        // TODO: estimate
        sAnswers answers;
        //[self estimate:&answers];
        answers.x = 100.0;
        answers.y = 150.0;
        answers.z = 100.0;
        
        [_delegate didCalculated:self withAnswers:answers];
    });
}


#pragma mark - interpolate(upSampling)

- (void)interpolateWithData:(float *)baseData
               responseData:(float *)resData {

    /* get base and response number of samples */
    unsigned int baseNumOfSamples = self.baseNumberOfSamples;
    unsigned int resNumOfSamples  = self.responseNumberOfSamples;
    
    if (baseNumOfSamples == resNumOfSamples) {
        for (int i=0; i<baseNumOfSamples; i++) {
            resData[i] = baseData[i];
        }
        return;
    }

    /* get 2^x */
    int baseLog2n = log2(baseNumOfSamples);
    int resLog2n  = log2(resNumOfSamples);
    
    /* setup base FFT */
    FFTSetup fftSetup = vDSP_create_fftsetup(baseLog2n, FFT_RADIX2);
    DSPSplitComplex baseComplex;
    baseComplex.realp = MEM_CALLOC(baseNumOfSamples, sizeof(float));
    baseComplex.imagp = MEM_CALLOC(baseNumOfSamples, sizeof(float));
    for (int i=0; i<baseNumOfSamples; i++) {
        baseComplex.realp[i] = baseData[i];
        baseComplex.imagp[i] = 0.0;
    }
    /* do FFT */
    vDSP_fft_zip(fftSetup, &baseComplex, 1, (vDSP_Length)baseLog2n, FFT_FORWARD);

    /* setup res FFT */
    FFTSetup fftResSetup = vDSP_create_fftsetup(resLog2n, FFT_RADIX2);
    DSPSplitComplex resComplex;
    resComplex.realp = MEM_CALLOC(resNumOfSamples, sizeof(float));
    resComplex.imagp = MEM_CALLOC(resNumOfSamples, sizeof(float));
    for (int i=0; i<baseNumOfSamples/2; i++) {
        resComplex.realp[i] = baseComplex.realp[i];
        resComplex.imagp[i] = baseComplex.imagp[i];
    }
    for (int i=resNumOfSamples-(baseNumOfSamples/2); i<resNumOfSamples; i++) {
        resComplex.realp[i] = baseComplex.realp[i-resNumOfSamples+baseNumOfSamples];
        resComplex.imagp[i] = baseComplex.imagp[i-resNumOfSamples+baseNumOfSamples];
    }
    
    /* do IFFT */
    vDSP_fft_zip(fftResSetup, &resComplex, 1, (vDSP_Length)resLog2n, FFT_INVERSE);

    /* set result */
    for (int i=0; i<resNumOfSamples; i++) {
        resData[i] = resComplex.realp[i] / pow(2, baseLog2n);
    }

    vDSP_destroy_fftsetup(fftSetup);
    vDSP_destroy_fftsetup(fftResSetup);
    free(baseComplex.realp);
    free(baseComplex.imagp);
    free(resComplex.realp);
    free(resComplex.imagp);
    return;
}


#pragma mark - calc cross-correlation function

- (void)calcCCFWithData:(double *)baseData
                subData:(double *)subData
                 result:(sCCFResult *)result {

    double *resultArray = MEM_CALLOC(kLimitSample * 2, sizeof(double));
    
    for (int i=kOffset; i<kLimitSample*2+kOffset; i++) {
        double tempBase = 0;
        double tempSub  = 0;
        for (int j=kLimitSample+kOffset; j<kRange; j++) {
            resultArray[i-kOffset] += baseData[i+j-kLimitSample-kOffset] * subData[j];
            tempBase += pow(baseData[i+j-kLimitSample-kOffset], 2);
            tempSub  += pow(baseData[j], 2);
        }
        
        resultArray[i-kOffset] /= sqrt(tempBase * tempSub);
        
        if (result->max < resultArray[i-kOffset]) {
            result->max = resultArray[i-kOffset];
            result->indexOfMax = i - kOffset;
        }
    }

    if (result->indexOfMax < kLimitSample - 1) {
        result->arrivalStatus    = kIsAheadBase;
        result->arrivalSampleLag = kLimitSample -1 - result->indexOfMax;
        result->arrivalTimeLag   = (double)result->arrivalSampleLag
                                   * (1 / (kSamplePer * pow(2, kPowerNumberOfTwo)));
    }
    else if ((result->indexOfMax == kLimitSample) || (result->indexOfMax == kLimitSample - 1)) {
        result->arrivalStatus    = kIsSame;
        result->arrivalSampleLag = 0;
        result->arrivalTimeLag   = 0.0;
    }
    else {
        result->arrivalStatus    = kIsAheadSub;
        result->arrivalSampleLag = kLimitSample + 1 - result->indexOfMax;
        result->arrivalTimeLag   = (double)result->arrivalSampleLag
                                   * (1 / (kSamplePer * pow(2, kPowerNumberOfTwo)));
    }

    free(resultArray);
}

- (void)estimate:(sAnswers *)ans {
    double drA = kSonic * _resultOtoA.arrivalTimeLag;
    double drB = kSonic * _resultOtoB.arrivalTimeLag;
    double drC = kSonic * _resultOtoC.arrivalTimeLag;
    /* powered */
    double p2_drA  = pow(drA, 2);
    double p2_drB  = pow(drB, 2);
    double p2_drC  = pow(drC, 2);
    double p2_dist = pow(kMicDist, 2);
    
    /* put BIG A, B, C to tmpOne, tmpTwo, tmpThree */
    double tmpOne   = 4 * (+ (3 * (+ p2_drA
                                   + p2_drB
                                   + p2_drC)
                              )
                           - 2 * (+ (drA * drB)
                                  + (drA * drC)
                                  + (drB * drC)
                                  + p2_dist)
                           );

    double tmpTwo   = 4 * (- 3 * (+ pow(drA, 3)
                                  + pow(drB, 3)
                                  + pow(drC, 3)
                                  )
                           + (p2_drA * (drB + drC))
                           + (p2_drB * (drA + drC))
                           + (p2_drC * (drA + drB))
                           + (p2_dist * (drA + drB + drC))
                           );

    double tmpThree = 1 * (+ (3 * (+ pow(kMicDist, 4)
                                   + pow(drA, 4)
                                   + pow(drB, 4)
                                   + pow(drC, 4)
                                   )
                              )
                           - ((2 * p2_dist) * (p2_drA + p2_drB + p2_drC))
                           - 2 * (+ (p2_drA * p2_drB)
                                  + (p2_drC * (p2_drA + p2_drB)
                                     )
                                  )
                           );
    
    double rO;
    if (!tmpOne) {
        rO = - 1 * (tmpThree / tmpTwo);
    }
    else {
        rO = - 1 * (tmpTwo / (2 * tmpOne))
             + (sqrt(pow(tmpTwo, 2)
                     - (4 * tmpOne * tmpTwo)
                     )
                / abs(2 * tmpOne));
    }
    
    double rA = rO - drA;
    double rB = rO - drB;
    double rC = rO - drC;
    double p2_rO = pow(rO, 2);
    double p2_rA = pow(rA, 2);
    double p2_rB = pow(rB, 2);
    double p2_rC = pow(rC, 2);
    
    ans->x = (p2_rA - p2_dist - p2_rO) / (2 * kMicDist);
    ans->y = (+ (2 * p2_rB)
             - p2_dist
             - p2_rO
             - p2_rA
             ) / (2 * sqrt(3) * kMicDist);
    ans->z = (+ (3 * p2_rC)
             - p2_dist
             - p2_rO
             - p2_rA
             - p2_rB
             ) / (2 * sqrt(6) * kMicDist);
    
    NSLog(@"[RESULT]: X=%.10f", ans->x);
    NSLog(@"[RESULT]: Y=%.10f", ans->y);
    NSLog(@"[RESULT]: Z=%.10f", ans->z);
}


#pragma mark - dump methods

- (void)dumpCCFResult:(sCCFResult *)result withName:(NSString *)name {
    NSLog(@"-------- DUMP %@ START --------", name);
    NSLog(@"indexOfMax: %d", result->indexOfMax);
    NSLog(@"max       : %f", result->max);
    if (result->arrivalStatus == kIsAheadSub) {
        NSLog(@"Sub is Arrival earlier than Base");
    }
    else if (result->arrivalStatus == kIsSame) {
        NSLog(@"Arrival time is Same");
    }
    else if (result->arrivalStatus == kIsAheadBase) {
        NSLog(@"Base is Arrival earlier than Sub");
    }
    NSLog(@"The SAMPLE LAG is %d sample", result->arrivalSampleLag);
    NSLog(@"The TIME LAG is %.12f second", result->arrivalTimeLag);
    NSLog(@"-------- DUMP %@ END --------", name);

}

@end
