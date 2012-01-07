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

        _inputQueue = dispatch_queue_create("EstimaCalculator", NULL);//dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        _resultOtoA.max = 0;
        _resultOtoB.max = 0;
        _resultOtoC.max = 0;
        NSLog(@"EstimaCalculator init DONE.");
    }
    return self;
}

- (void)dealloc {
    free(_interpolatedDataO);
    free(_interpolatedDataA);
    free(_interpolatedDataB);
    free(_interpolatedDataC);
    dispatch_release(_inputQueue);
}


#pragma mark - delegate method

- (void)inputBufferDidFilledBuffer:(AudioBufferList *)bufferList
                   withCountNumber:(unsigned int)num {

    if (_isCalculating == YES) {
        _count = num;
        NSLog(@" ");
        NSLog(@"<%d>BUFFER DID FILLED. START CALUCULATE!", _count);
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
        FILE *bfp = fopen("/Users/kosuke/desktop/ccfwav_base.txt", "w");
        FILE *sfp = fopen("/Users/kosuke/desktop/ccfwavs_sub.txt", "w");
        for (int i=0; i<self.responseNumberOfSamples; i++) {
            fprintf(bfp, "%d %f\n", i, upedBase[i]);
            fprintf(sfp, "%d %f\n", i, upedSub[i]);
        }
        fclose(bfp);
        fclose(sfp);

        [self calcCCFWithData:upedBase subData:upedSub result:&ccfresult name:@"testBaseToSub"];
        [self dumpCCFResult:&ccfresult withName:@"test"];
        NSLog(@"OK");
        
        free(upedBase);
        free(upedSub);
        free(toUpBaseTmp);
        free(toUpSubTmp);
        free(updB);
        free(updS);
        return;
        */
        //
        [self calculateWithABL:bufferList];
    }
    else {
        NSLog(@"calcurator is stopping.");
    }
}


#pragma mark - calculation CORE

- (void)calculateWithABL:(AudioBufferList *)bufferList {

    unsigned int num = _count;
    float *dataO = (float *)bufferList->mBuffers[0].mData;
    float *dataA = (float *)bufferList->mBuffers[1].mData;
    float *dataB = (float *)bufferList->mBuffers[2].mData;
    float *dataC = (float *)bufferList->mBuffers[3].mData;
    
    //
    /*
    float *dataO = MEM_CALLOC(numOfFrames, sizeof(float));
    float *dataA = MEM_CALLOC(numOfFrames, sizeof(float));
    float *dataB = MEM_CALLOC(numOfFrames, sizeof(float));
    float *dataC = MEM_CALLOC(numOfFrames, sizeof(float));
    
    AudioDataHandle *sanyon = [[AudioDataHandle alloc] initWithWavFile:@"/Users/kosuke/Desktop/measurement_34.wav"];
    AudioDataHandle *ichini = [[AudioDataHandle alloc] initWithWavFile:@"/Users/kosuke/Desktop/measurement_12.wav"];
    for (int i=0; i<(96000*3); i++) {
        dataO[i] = (float)[sanyon access:0 atIndex:i+(96000*4)];
        dataA[i] = (float)[sanyon access:1 atIndex:i+(96000*4)];
        dataB[i] = (float)[ichini access:0 atIndex:i+(96000*4)];
        dataC[i] = (float)[ichini access:1 atIndex:i+(96000*4)];
    }
     */
    //
    
    /* debug
    for (int i=0; i<50; i++) {
        printf(">ch: %.10f >1ch: %.10f >2ch: %.10f >3ch: %.10f\n", dataO[i], dataA[i], dataB[i], dataC[i]);
    }
     */
    [self interpolateWithData:dataO responseData:_interpolatedDataO];
    [self interpolateWithData:dataA responseData:_interpolatedDataA];
    [self interpolateWithData:dataB responseData:_interpolatedDataB];
    [self interpolateWithData:dataC responseData:_interpolatedDataC];

    /*
    char path[100];
     sprintf(path, "/Users/kosuke/Desktop/EstimaDebug/upedO_%d.txt", _count);
        FILE *fp = fopen(path, "w");
    for (int i=0; i<self.responseNumberOfSamples; i++) {
            fprintf(fp, "%d %10f\n", i, _interpolatedDataO[i]);
        }
    fclose(fp);
     */
    
    unsigned int sampleRate = kInputDataSampleRate * pow(2.0, kPowerNumberOfTwo);
    unsigned int numOfSamples = self.responseNumberOfSamples;

    void **temp = [AudioDataHandle prepareInitWithDatas:kIsFloat
                                          numOfChannels:/*2*/4
                                              firstData:_interpolatedDataO,
                   _interpolatedDataA, _interpolatedDataB, _interpolatedDataC];
    /* debug
    NSLog(@"temp");
    for (int i=0; i<50; i++) {
        printf("inted: %.10e | temp: %.10f\n", _interpolatedDataA[i], ((float **)temp)[1][i]);
    }
     */
    AudioDataHandle *audioDatas
    = [[AudioDataHandle alloc] initWithDatas:temp
                                numOfSamples:numOfSamples
                               numOfChannels:/*2*/4
                               samplesPerSec:sampleRate
                                    dataType:kIsFloat];
    // OK
    //[audioDatas dumpDatas];
    //[audioDatas dumpInfo:@"test"];
    free(temp);
    
    char hoge[100];
    char foo[100];
    char bar[100];
    char baz[100];
    sprintf(hoge, "/Users/kosuke/Desktop/EstimaResult/wavs/upedO_%d.txt", _count);
    sprintf(foo, "/Users/kosuke/Desktop/EstimaResult/wavs/upedA_%d.txt", _count);
    sprintf(bar, "/Users/kosuke/Desktop/EstimaResult/wavs/upedB_%d.txt", _count);
    sprintf(baz, "/Users/kosuke/Desktop/EstimaResult/wavs/upedC_%d.txt", _count);
    FILE *zero = fopen(hoge, "w");
    FILE *one = fopen(foo, "w");
    FILE *two = fopen(bar, "w");
    FILE *three = fopen(baz, "w");
    for (int i=kOffset; i<kRange; i++) {
        fprintf(zero, "%d %f\n", i, [audioDatas access:0 atIndex:i]);
        fprintf(one, "%d %f\n", i, [audioDatas access:1 atIndex:i]);
       fprintf(two, "%d %f\n", i, [audioDatas access:2 atIndex:i]);
        fprintf(three, "%d %f\n", i, [audioDatas access:3 atIndex:i]);
    }
    fclose(zero);
    fclose(one);
    fclose(two);
    fclose(three);
    
    [self calcCCFWithData:[audioDatas dataWithChannel:0]
                  subData:[audioDatas dataWithChannel:0]
                   result:&_resultOtoA
                     name:@"self"];
    [self calcCCFWithData:[audioDatas dataWithChannel:0]
                  subData:[audioDatas dataWithChannel:1]
                   result:&_resultOtoA
                     name:@"OtoA"];
    [self calcCCFWithData:[audioDatas dataWithChannel:0]
                  subData:[audioDatas dataWithChannel:2]
                   result:&_resultOtoB
                     name:@"OtoB"];
    [self calcCCFWithData:[audioDatas dataWithChannel:0]
                  subData:[audioDatas dataWithChannel:3]
                   result:&_resultOtoC
                     name:@"OtoC"];
    [self dumpCCFResult:&_resultOtoA withName:@"OtoA"];
    [self dumpCCFResult:&_resultOtoB withName:@"OtoB"];
    [self dumpCCFResult:&_resultOtoC withName:@"OtoC"];

    /* check ccf error */
    if ((_resultOtoA.arrivalStatus
         + _resultOtoB.arrivalStatus
         + _resultOtoC.arrivalStatus) < 2) {
        NSLog(@"[ERROR]: CalcCCF error.");
        return;
    }

    dispatch_async(_inputQueue, ^{
        
        sAnswers answers;
        [self estimate:&answers];
        //answers.x = 100.0;
        //answers.y = 150.0;
        //answers.z = 100.0;
        
        [_delegate didCalculated:self
                     withAnswers:answers
                        countNum:num];
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
            resData[i] = ((fabs(baseData[i]) - 0.0005) < 0) ? 0 : baseData[i]; //comp
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
        double tmp = resComplex.realp[i] / pow(2, baseLog2n);
        resData[i] = tmp;//((fabs(tmp) - 0.0005) < 0) ? 0 : tmp;
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
                 result:(sCCFResult *)result
                   name:(NSString *)name {

    result->max = 0;
    double *resultArray = MEM_CALLOC(kLimitSample * 2, sizeof(double));
    const char *cName = [name UTF8String];
    char path[100];
    sprintf(path, "/Users/kosuke/Desktop/EstimaResult/ccf/ccf%s_%d.txt", cName, _count);
    FILE *fp = fopen(path, "w");
    for (int i=kOffset; i<kLimitSample*2+kOffset; i++) {
        double tempBase = 0.0;
        double tempSub  = 0.0;
        for (int j=kLimitSample+kOffset; j<kRange; j++) {
            resultArray[i-kOffset] += baseData[i+j-kLimitSample-kOffset] * subData[j];
            tempBase += pow(baseData[i+j-kLimitSample-kOffset], 2);
            tempSub  += pow(baseData[j], 2);
        }
        
        resultArray[i-kOffset] /= sqrt(tempBase * tempSub);
        fprintf(fp, "%d %f\n", i - kOffset, resultArray[i-kOffset]);
        if (result->max < resultArray[i-kOffset]) {
            result->max = resultArray[i-kOffset];
            result->indexOfMax = i - kOffset;
        }
    }
    fclose(fp);
    if (result->indexOfMax < kLimitSample - 1) {
        result->arrivalStatus    = kIsAheadBase;
        result->arrivalSampleLag = - (kLimitSample -1 - result->indexOfMax);
        result->arrivalTimeLag   = (double)result->arrivalSampleLag * kUpedPerSample;
    }
    else if ((result->indexOfMax == kLimitSample) || (result->indexOfMax == kLimitSample - 1)) {
        result->arrivalStatus    = kIsSame;
        result->arrivalSampleLag = 0;
        result->arrivalTimeLag   = 0.0;
    }
    else {
        result->arrivalStatus    = kIsAheadSub;
        result->arrivalSampleLag = - (kLimitSample + 1 - result->indexOfMax);
        result->arrivalTimeLag   = (double)result->arrivalSampleLag * kUpedPerSample;
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
    NSLog(@"tmpDONE");
    NSLog(@"tA:%f |tB:%f |tC:%f", tmpOne, tmpTwo, tmpThree);
    double rO;
    if (tmpOne == 0.0) {
        rO = - 1 * (tmpThree / tmpTwo);
    }
    else {
        rO = - 1 * (tmpTwo / (2 * tmpOne))
             + (sqrt(pow(tmpTwo, 2)
                     - (4 * tmpOne * tmpThree)
                     )
                / fabs(2 * tmpOne));
//        rO = - 1 * (tmpTwo / (2 * tmpOne))
//        - (sqrt(pow(tmpTwo, 2)
//                - (4 * tmpOne * tmpThree)
//                )
//           / (2 * tmpOne));

        NSLog(@"tAisnot 0");
        
    }
    NSLog(@"rO:%f", rO);
    double rA = rO - drA;
    double rB = rO - drB;
    double rC = rO - drC;
    double p2_rO = pow(rO, 2);
    double p2_rA = pow(rA, 2);
    double p2_rB = pow(rB, 2);
    double p2_rC = pow(rC, 2);
    
    double tmpX = (p2_rA - p2_dist - p2_rO) / (2 * kMicDist);
    double tmpY = (+ (2 * p2_rB)
                   - p2_dist
                   - p2_rO
                   - p2_rA
                   ) / (2 * sqrt(3) * kMicDist);
    double tmpZ = (+ (3 * p2_rC)
                   - p2_dist
                   - p2_rO
                   - p2_rA
                   - p2_rB
                   ) / (2 * sqrt(6) * kMicDist);
    //ans->x = (fabs(tmpX) > 50) ? tmpX : 0;
    //ans->z = (fabs(tmpZ) > 50) ? tmpZ : 0;
    //ans->y = (fabs(tmpY) > 50) ? tmpY : 0;
    ans->x = tmpX;
    ans->y = tmpY;
    ans->z = tmpZ;
    
    NSLog(@"%d[RESULT]: X=%f", _count, ans->x);
    NSLog(@"%d[RESULT]: Y=%f", _count, ans->y);
    NSLog(@"%d[RESULT]: Z=%f", _count, ans->z);
    
}

#pragma mark - dump methods

- (void)dumpCCFResult:(sCCFResult *)result withName:(NSString *)name {
    NSLog(@"-------- DUMP %@ START (%d) --------", name, _count);
    NSLog(@"<%@%d>indexOfMax: %d", name, _count, result->indexOfMax);
    NSLog(@"<%@%d>max       : %f", name, _count, result->max);
    if (result->arrivalStatus == kIsAheadSub) {
        NSLog(@"<%@%d>Sub is Arrival earlier than Base", name, _count);
    }
    else if (result->arrivalStatus == kIsSame) {
        NSLog(@"<%@%d>Arrival time is Same", name, _count);
    }
    else if (result->arrivalStatus == kIsAheadBase) {
        NSLog(@"<%@%d>Base is Arrival earlier than Sub", name, _count);
    }
    NSLog(@"<%@%d>The SAMPLE LAG is %d sample", name, _count, result->arrivalSampleLag);
    NSLog(@"<%@%d>The TIME LAG is %.12f second", name, _count, result->arrivalTimeLag);
    NSLog(@"-------- DUMP %@ END (%d)--------", name, _count);

}

@end
