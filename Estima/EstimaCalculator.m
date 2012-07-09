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
@synthesize isTest         = _isTest;
@synthesize numberOfFrames = _numberOfFrames;

@dynamic baseNumberOfSamples;
- (unsigned int)baseNumberOfSamples {
    return NextPowerOfTwo((double)kRange);
}
@dynamic responseNumberOfSamples;
- (unsigned int)responseNumberOfSamples {
    return (self.baseNumberOfSamples * pow(2, kPowerNumberOfTwo));
}
@dynamic baseLog2n;
- (unsigned int)baseLog2n {
    return (int)log2(self.baseNumberOfSamples);
}
@dynamic usingRange;
- (unsigned int)usingRange {
    return (NextPowerOfTwo(kLimitSample * kComp) * 2);
}
@dynamic upedRange;
- (unsigned int)upedRange {
    return (self.usingRange * pow(2.0, kPowerNumberOfTwo));
}
@dynamic usingLog2n;
- (unsigned int)usingLog2n {
    return log2(self.usingRange);
}
@dynamic upedLog2n;
- (unsigned int)upedLog2n {
    return log2(self.upedRange);
}



#pragma mark - initialize

- (id)init {
    self = [super init];
    if (self) {
        //
        _fftBaseSetup  = vDSP_create_fftsetupD(self.baseLog2n, kFFTRadix2);
        _fftSubSetup   = vDSP_create_fftsetupD(self.baseLog2n, kFFTRadix2);
        _fftResSetup   = vDSP_create_fftsetupD(self.baseLog2n, kFFTRadix2);
        _fftUsingSetup = vDSP_create_fftsetupD(self.usingLog2n, kFFTRadix2);
        _fftUpedSetup  = vDSP_create_fftsetupD(self.upedLog2n, kFFTRadix2);
        //

        /*
        _interpolatedDataO = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        _interpolatedDataA = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        _interpolatedDataB = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        _interpolatedDataC = MEM_CALLOC(self.responseNumberOfSamples, sizeof(float));
        */
        _inputQueue = dispatch_queue_create("EstimaCalculator", NULL);

        _resultOtoA.max = 0.0;
        _resultOtoB.max = 0.0;
        _resultOtoC.max = 0.0;
        NSLog(@"EstimaCalculator init DONE.");
        //
        _isTest = NO;
        //
    }
    return self;
}

- (void)dealloc {
    vDSP_destroy_fftsetupD(_fftBaseSetup); ///
    vDSP_destroy_fftsetupD(_fftSubSetup); ///
    vDSP_destroy_fftsetupD(_fftResSetup); ///
    vDSP_destroy_fftsetupD(_fftUsingSetup); ///
    vDSP_destroy_fftsetupD(_fftUpedSetup); ///
    /*
    free(_interpolatedDataO);
    free(_interpolatedDataA);
    free(_interpolatedDataB);
    free(_interpolatedDataC);
     */
    free(_bufferO);
    free(_bufferA);
    free(_bufferB);
    free(_bufferC);
    dispatch_release(_inputQueue);
}


#pragma mark - delegate method

- (void)inputBufferDidFilledBuffer:(AudioBufferList *)bufferList
                withNumberOfFrames:(unsigned int)numOfFrames
                       countNumber:(unsigned int)num {

    NSDate *startTimeOfFilled = [NSDate date];
    NSTimeInterval since;
    _count = num;
    _numberOfFrames = numOfFrames;

    if (_isCalculating == YES) {
        printf("\n");
        NSLog(@"<%d>BUFFER DID FILLED. START CALUCULATION!", _count);

        // debug
        if (_isTest) {
            //_isTest = NO;
            // debug ccffft

            FFTSetupD testBaseSetup = vDSP_create_fftsetupD(5, kFFTRadix2);
            FFTSetupD testResSetup = vDSP_create_fftsetupD(6, kFFTRadix2);
            DSPDoubleSplitComplex testBaseComplex;
            DSPDoubleSplitComplex testResComplex;
            testBaseComplex.realp = MEM_CALLOC(32, sizeof(double));
            testBaseComplex.imagp = MEM_CALLOC(32, sizeof(double));
            testResComplex.realp = MEM_CALLOC(64, sizeof(double));
            testResComplex.imagp = MEM_CALLOC(64, sizeof(double));
            for (int i=0; i<32; i++) {
                testBaseComplex.realp[i] = sin(i);//(double)i / 50.0;
                testBaseComplex.imagp[i] = 0.0;
            }
            for (int i=0; i<32; i++) {
                NSLog(@"%d: signal->%f\n", i, testBaseComplex.realp[i]);
            }
            vDSP_fft_zipD(testBaseSetup, &testBaseComplex, 1, 5, FFT_FORWARD);

            NSLog(@" ");
            NSLog(@"ffted\n");
            for (int i=0; i<32; i++) {
                NSLog(@"%d: real->%f imag->%f\n", i, testBaseComplex.realp[i], testBaseComplex.imagp[i]);
            }
            for (int i=0; i<16; i++) {
                testResComplex.realp[i] = testBaseComplex.realp[i];
                testResComplex.imagp[i] = testBaseComplex.imagp[i];
            }
            for (int i=48; i<64; i++) {
                testResComplex.realp[i] = testBaseComplex.realp[i-32];
                testResComplex.imagp[i] = testBaseComplex.imagp[i-32];
            }

            NSLog(@" ");
            NSLog(@"dainyuu\n");
            for (int i=0; i<64; i++) {
                NSLog(@"%d: real->%f imag->%f\n", i, testResComplex.realp[i], testResComplex.imagp[i]);
            }

            NSLog(@" ");
            NSLog(@"interped");
            vDSP_fft_zipD(testResSetup, &testResComplex, 1, 6, FFT_INVERSE);
            for (int i=0; i<64; i++) {
                NSLog(@"%d: real->%f imag->%f\n", i, testResComplex.realp[i] / 32, testResComplex.imagp[i] / 32);
            }


            free(testBaseComplex.realp);
            free(testBaseComplex.imagp);
            vDSP_destroy_fftsetupD(testBaseSetup);
            free(testResComplex.realp);
            free(testResComplex.imagp);
            vDSP_destroy_fftsetupD(testResSetup);
            return;


            AudioDataHandle *baseData
            = [[AudioDataHandle alloc] initWithWavFile:@"/Users/kosuke/Downloads/1013_cross_base_mono.wav"];
            FILE *bfp = fopen("/Users/kosuke/Acoust/ccf0203/wav_behind13thanBase_2.csv", "w");
            unsigned int count        = 96000;
            unsigned int limit_sample = 15;
            int zure                  = 13;
            unsigned int range        = limit_sample * 2; //30 = 15 * 2 (0 ~ 29)
            unsigned int area_max     = limit_sample;     //15
            unsigned int area_min     = limit_sample - 1; //14
            unsigned int start_point  = limit_sample; //15
            double *base = MEM_CALLOC(count, sizeof(double));
            double *sub  = MEM_CALLOC(count, sizeof(double));
            for (int i=1000; i<count+1000; i++) {
                base[i-1000] = [baseData access:0 atIndex:i];
                sub[i-1000]  = [baseData access:0 atIndex:i+zure];
                fprintf(bfp, "%f, %f\n", (i - 1000) * 0.0000104167, sub[i-1000]);
            }
            fclose(bfp);
            stCCFResult result;
            result.max = 0.0;
            result.indexOfMax = 0;
            double *results = MEM_CALLOC(range, sizeof(double));

            FILE *fp = fopen("/Users/kosuke/Acoust/ccf0203/ccf_behind13thanBase_2.csv", "w");
            for (int i=0; i<range; i++) {
                double tempBase = 0.0;
                double tempSub  = 0.0;
                for (int j=start_point; j<count; j++) {
                    results[i] += base[i+j-start_point] * sub[j];
                    tempBase   += pow(base[i+j-start_point], 2.0);
                    tempSub    += pow(sub[j], 2.0);
                }
                results[i] /= sqrt(tempBase * tempSub);
                fprintf(fp, "%f %f\n", i * 0.0000104167, results[i]);
                if (result.max < results[i]) {
                    result.max = results[i];
                    result.indexOfMax = i;
                }
            }
            fclose(fp);

            if (result.indexOfMax < limit_sample) {// index=k limit_sample=P
                result.arrivalStatus    = kIsAheadSub;
                result.arrivalSampleLag = result.indexOfMax - limit_sample; // area_min
                result.arrivalTimeLag   = (double)result.arrivalSampleLag * kPerSample;
            }
            else if (result.indexOfMax == limit_sample) {
                result.arrivalStatus    = kIsSame;
                result.arrivalSampleLag = 0;
                result.arrivalTimeLag   = 0.0;
            }
            else {
                result.arrivalStatus    = kIsAheadBase;
                result.arrivalSampleLag = result.indexOfMax - limit_sample; // area_max
                result.arrivalTimeLag   = (double)result.arrivalSampleLag * kPerSample;
            }

            [self dumpCCFResult:&result withName:@"test"];
            free(base);
            free(sub);
            free(results);


//            AudioDataHandle *subData
//            = [[AudioDataHandle alloc] initWithWavFile:@"/Users/kosuke/Downloads/1013_cross_sub_mono.wav"];
//
//            unsigned int range = 32;//self.baseNumberOfSamples;
//            vDSP_Length baseLog2n = log2(range);
//            FFTSetupD baseSetup = vDSP_create_fftsetupD(baseLog2n, kFFTRadix2);
//            DSPDoubleSplitComplex baseComplex;
//            baseComplex.realp = MEM_CALLOC(range, sizeof(double));
//            baseComplex.imagp = MEM_CALLOC(range, sizeof(double));
//            for (int i=0; i<range; i++) {
//                baseComplex.realp[i] = [baseData access:0 atIndex:i];
//            }
//            /*
//            AudioBufferList *buf;
//            buf = createAudioBufferList(2, _numberOfFrames * 4);
//            buf->mBuffers[0].mData = floatBase;
//            buf->mBuffers[1].mData = floatSub;
//            [self neoCalcWithABL:buf];
//            removeAudioBufferList(buf);
//             */
//            NSLog(@"start");
//            vDSP_fft_zipD(baseSetup, &baseComplex, 1, baseLog2n, FFT_FORWARD);
//
//            FILE *fp = fopen("/Users/kosuke/Acoust/fftTest.txt", "w");
//            for (int i=0; i<range; i++) {
//                double temp = sqrt(pow(baseComplex.realp[i], 2.0) + pow(baseComplex.imagp[i], 2.0));
//                fprintf(fp, "%d %f\n", i, temp);
//            }
//            fclose(fp);

            NSLog(@"done");
            return;
        }
        //

        [self neoCalcWithABL:bufferList]; // 4

        //[self newCalcWithABL:bufferList]; // 3

        //[self calcWithABL:bufferList]; // 1

        //[self calculateWithABL:bufferList]; // 2
    }
    else {
        NSLog(@"calcurator is stopping.");
    }

    since = - [startTimeOfFilled timeIntervalSinceNow];
    NSLog(@"<%d>DONE TIME: %f", _count, since);
}

- (void)neoCalcWithABL:(AudioBufferList *)bufferList {

    NSDate *startTimeOfCalc = [NSDate date];
    NSTimeInterval since;

    unsigned int margin   = 300;
    unsigned int bufRange = self.baseNumberOfSamples + margin;

    float *dataO = (float *)bufferList->mBuffers[0].mData;
    float *dataA = (float *)bufferList->mBuffers[1].mData;
    float *dataB = (float *)bufferList->mBuffers[2].mData;///
    float *dataC = (float *)bufferList->mBuffers[3].mData;///

    if (_count == 1) {
        _bufferO = MEM_CALLOC(bufRange, sizeof(float));
        _bufferA = MEM_CALLOC(bufRange, sizeof(float));
        _bufferB = MEM_CALLOC(bufRange, sizeof(float));
        _bufferC = MEM_CALLOC(bufRange, sizeof(float));
    }

    unsigned int rangeCount = (int)(bufRange / _numberOfFrames);

    if (bufRange > _numberOfFrames) {
        if (_count <= rangeCount) {
            for (int i=_pos; i<_numberOfFrames; i++) {
                _bufferO[i] =  dataO[i];
                _bufferA[i] =  dataA[i];
                _bufferB[i] =  dataB[i];
                _bufferC[i] =  dataC[i];
            }
            _pos += _numberOfFrames;

            since = - [startTimeOfCalc timeIntervalSinceNow];
            NSLog(@"%d count <= rangeCount: %f", _count, since);

            return;
        }
        else {
            unsigned int boundary = bufRange - _numberOfFrames;
            unsigned int reminder = _pos - boundary;

            for (int i=0; i<boundary; i++) {
                _bufferO[i] = _bufferO[i+reminder];
                _bufferA[i] = _bufferA[i+reminder];
                _bufferB[i] = _bufferB[i+reminder];
                _bufferC[i] = _bufferC[i+reminder];
            }
            for (int i=boundary; i<bufRange; i++) {
                _bufferO[i] = dataO[i-(boundary)]; // 0 ~ < _numberOfFrames
                _bufferA[i] = dataA[i-(boundary)];
                _bufferB[i] = dataB[i-(boundary)];
                _bufferC[i] = dataC[i-(boundary)];
            }
            _pos = bufRange;
        }
    }
    else { // bufRange < _numOfFrames
        for (int i=0; i<bufRange; i++) {
            _bufferO[i] = dataO[i];
            _bufferA[i] = dataA[i];
            _bufferB[i] = dataB[i];
            _bufferC[i] = dataC[i];
        }
    }

    since = - [startTimeOfCalc timeIntervalSinceNow];
    NSLog(@"%d start group: %f", _count, since);

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();

    dispatch_group_async(group, queue, ^{
        [self neoCCFWithBaseData:_bufferO
                         subData:_bufferA
                          result:&_resultOtoA
                            name:@"OtoA"];
    });
    dispatch_group_async(group, queue, ^{
        [self neoCCFWithBaseData:_bufferO
                         subData:_bufferB
                          result:&_resultOtoB
                            name:@"OtoB"];
    });
    dispatch_group_async(group, queue, ^{
        [self neoCCFWithBaseData:_bufferO
                         subData:_bufferC
                          result:&_resultOtoC
                            name:@"OtoC"];
    });

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);

    since = - [startTimeOfCalc timeIntervalSinceNow];
    NSLog(@"%d end group: %f", _count, since);


    //[self dumpCCFResult:&_resultOtoA withName:@"OtoA"];
    //[self dumpCCFResult:&_resultOtoB withName:@"OtoB"];
    //[self dumpCCFResult:&_resultOtoC withName:@"OtoC"];

    /* check ccf error */
    if ((_resultOtoA.arrivalStatus
         + _resultOtoB.arrivalStatus
         + _resultOtoC.arrivalStatus) < 2) {
        NSLog(@"[ERROR]: Calc CCF failed.");
        return;
    }

    dispatch_async(_inputQueue, ^{
        stAnswers answers;
        [self estimate:&answers];
        [_delegate didCalculated:self
                     withAnswers:answers
                        countNum:_count];
    });
}

- (void)neoCCFWithBaseData:(float *)baseData
                   subData:(float *)subData
                    result:(stCCFResult *)result
                      name:(NSString *)name {

    NSDate *startTimeOfCCF = [NSDate date];
    NSTimeInterval since, temp;
    unsigned int num = _count;

    result->max = 0.0;
    result->indexOfMax = 0;

    /* prepare */
    unsigned int bNumOfSamples = self.baseNumberOfSamples;
    int bLog2n = self.baseLog2n;

    since = - [startTimeOfCCF timeIntervalSinceNow];
    NSLog(@"%d<%@>prepare first: %f", num, name, since - temp);

    DSPDoubleSplitComplex bComplex, sComplex;

    bComplex.realp = MEM_CALLOC(bNumOfSamples, sizeof(double));
    bComplex.imagp = MEM_CALLOC(bNumOfSamples, sizeof(double));
    sComplex.realp = MEM_CALLOC(bNumOfSamples, sizeof(double));
    sComplex.imagp = MEM_CALLOC(bNumOfSamples, sizeof(double));

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>setuped: %f", num, name, since - temp);

    ///
    //const char *cName = [name UTF8String];
    ///

    for (int i=0; i<bNumOfSamples; i++) {
        bComplex.realp[i] = (double)baseData[i+kOffset];
        sComplex.realp[i] = (double)subData[i+kLimitSample+kOffset];
    }
    for (int i=bNumOfSamples-kLimitSample; i<bNumOfSamples; i++) { ///test
        sComplex.realp[i] = 0.0;
    }

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>:substituted %f", num, name, since - temp);

    /* fft */
    vDSP_fft_zipD(_fftBaseSetup, &bComplex, 1, (vDSP_Length)bLog2n, FFT_FORWARD); ///
    vDSP_fft_zipD(_fftSubSetup, &sComplex, 1, (vDSP_Length)bLog2n, FFT_FORWARD); ///

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>:ffted %f", num, name, since - temp);

    /* prepare result */
    DSPDoubleSplitComplex rComplex;
    rComplex.realp = MEM_CALLOC(bNumOfSamples, sizeof(double));
    rComplex.imagp = MEM_CALLOC(bNumOfSamples, sizeof(double));

    for (int i=0; i<bNumOfSamples; i++) {
        rComplex.realp[i] = bComplex.realp[i] * sComplex.realp[i]
                          + bComplex.imagp[i] * sComplex.imagp[i];
        rComplex.imagp[i] = bComplex.imagp[i] * sComplex.realp[i]
                          - bComplex.realp[i] * sComplex.imagp[i];
    }
    // test
    //vDSP_vmmaD(bComplex.realp, 1, sComplex.realp, 1, bComplex.imagp, 1, sComplex.imagp, 1, rComplex.realp, 1, bNumOfSamples);
    //vDSP_vmmsbD(bComplex.imagp, 1, sComplex.realp, 1, bComplex.realp, 1, sComplex.imagp, 1, rComplex.imagp, 1, bNumOfSamples);

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>:cros spectaraled %f", num, name, since - temp);

    vDSP_fft_zipD(_fftResSetup, &rComplex, 1, (vDSP_Length)bLog2n, FFT_INVERSE); ///

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>:inversed %f", num, name, since - temp);

    /* ccf upsampling */
    unsigned int usingRange = self.usingRange;
    unsigned int upedRange  = self.upedRange;
    int usingLog2n          = self.usingLog2n;
    int upedLog2n           = self.upedLog2n;

    DSPDoubleSplitComplex usingComplex, upedComplex;
    usingComplex.realp = MEM_CALLOC(usingRange, sizeof(double));
    usingComplex.imagp = MEM_CALLOC(usingRange, sizeof(double));
    upedComplex.realp  = MEM_CALLOC(upedRange, sizeof(double));
    upedComplex.imagp  = MEM_CALLOC(upedRange, sizeof(double));

    ///
    //char nopath[100];
    //sprintf(nopath, "/Users/kosuke/Acoust/neo/ccf/noup_%s_up%d_%d.txt", cName, (int)kPowerNumberOfTwo, num);
    //FILE *nop = fopen(nopath, "w");
    for (int i=0; i<usingRange; i++) {
        usingComplex.realp[i] = rComplex.realp[i] / pow(2.0, bLog2n);
        usingComplex.imagp[i] = rComplex.imagp[i] / pow(2.0, bLog2n);
        //fprintf(nop, "%d %f\n", i, usingComplex.realp[i]);
    }
    //fclose(nop);
    ///

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>:ccf fft setuped %f", num, name, since - temp);

    /* fft */
    vDSP_fft_zipD(_fftUsingSetup, &usingComplex, 1, (vDSP_Length)usingLog2n, FFT_FORWARD);

    /// test power spectral
    //char tespath[100];
    //sprintf(tespath, "/Users/kosuke/Acoust/neo/test/spectral_%s_up%d_%d.txt", cName, (int)kPowerNumberOfTwo, num);
    //FILE *testp = fopen(tespath, "w");
    //for (int i=0; i<usingRange; i++) {
        //double temp = pow(usingComplex.realp[i], 2.0) + pow(usingComplex.imagp[i], 2.0);
        //fprintf(testp, "%d %f\n", i, sqrt(temp));
    //}
    //fclose(testp);
    ///

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>:ccf ffted %f", num, name, since - temp);

    /* interpolate */
    for (int i=0; i<=usingRange/2; i++) {
        upedComplex.realp[i] = usingComplex.realp[i];
        upedComplex.imagp[i] = usingComplex.imagp[i];
    }
    for (int i=(upedRange-usingRange/2)/*, j=usingRange/2*/; i<upedRange; i++/*, j--*/) {
        upedComplex.realp[i] = usingComplex.realp[i-upedRange+usingRange];
        upedComplex.imagp[i] = usingComplex.imagp[i-upedRange+usingRange];
        // 単純に半分っぽい部分で反転して貼り付けると結果に誤差が出る
        //upedComplex.realp[i] = usingComplex.realp[j];
        //upedComplex.imagp[i] = usingComplex.imagp[j];
    }

    /* inverse */
    vDSP_fft_zipD(_fftUpedSetup, &upedComplex, 1, (vDSP_Length)upedLog2n, FFT_INVERSE);

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>:ccf inversed %f", num, name, since - temp);

    ///
    //char uppath[100];
    //sprintf(uppath, "/Users/kosuke/Acoust/neo/ccf/uped_%s_up%d_%d.txt", cName, (int)kPowerNumberOfTwo, num);
    //FILE *upp = fopen(uppath, "w");
    for (int i=0; i<kUpedLimitSample*2; i++) {
        double temp = upedComplex.realp[i] / pow(2.0, usingLog2n);
        if (result->max < temp) {
            result->max = temp;
            result->indexOfMax = i;
        }
        //fprintf(upp, "%d %f\n", i, temp);
    }
    //fclose(upp);
    ///

    /* set result */
    if (result->indexOfMax <  kUpedLimitSample) {
        result->arrivalStatus = kIsAheadSub;
        result->arrivalSampleLag = result->indexOfMax - kUpedLimitSample;
        result->arrivalTimeLag = (double)result->arrivalSampleLag * kUpedPerSample;
    }
    else if (result->indexOfMax == kUpedLimitSample) {
        result->arrivalStatus    = kIsSame;
        result->arrivalSampleLag = 0;
        result->arrivalTimeLag   = 0.0;
    }
    else {
        result->arrivalStatus    = kIsAheadBase;
        result->arrivalSampleLag = result->indexOfMax - kUpedLimitSample;
        result->arrivalTimeLag   = (double)result->arrivalSampleLag * kUpedPerSample;
    }

    since = - [startTimeOfCCF timeIntervalSinceNow];
    NSLog(@"%d<%@> DONE CCF ALL: %f", num, name, since);

    free(bComplex.realp);
    free(bComplex.imagp);
    free(sComplex.realp);
    free(sComplex.imagp);
    free(rComplex.realp);
    free(rComplex.imagp);
    free(usingComplex.realp);
    free(usingComplex.imagp);
    free(upedComplex.realp);
    free(upedComplex.imagp);
}


// ccfしてからその範囲にupsampling
- (void)newCalcWithABL:(AudioBufferList *)bufferList {
    NSDate *startTimeOfCalc = [NSDate date];
    NSTimeInterval since;
    unsigned int num = _count;

    float *dataO = (float *)bufferList->mBuffers[0].mData;
    float *dataA = (float *)bufferList->mBuffers[1].mData;
    float *dataB = (float *)bufferList->mBuffers[2].mData;
    float *dataC = (float *)bufferList->mBuffers[3].mData;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();

    dispatch_group_async(group, queue, ^{
        [self newCCFWithBaseData:dataO
                         subData:dataA
                          result:&_resultOtoA
                            name:@"OtoA"];
    });
    dispatch_group_async(group, queue, ^{
        [self newCCFWithBaseData:dataO
                         subData:dataB
                          result:&_resultOtoB
                            name:@"OtoB"];
    });
    dispatch_group_async(group, queue, ^{
        [self newCCFWithBaseData:dataO
                         subData:dataC
                          result:&_resultOtoC
                            name:@"OtoC"];
    });

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);

    since = - [startTimeOfCalc timeIntervalSinceNow];
    NSLog(@"<%d> DONE dispatch_group: %f", num, since);

    [self dumpCCFResult:&_resultOtoA withName:@"OtoA"];
    [self dumpCCFResult:&_resultOtoB withName:@"OtoB"];
    [self dumpCCFResult:&_resultOtoC withName:@"OtoC"];

    /* check ccf error */
    if ((_resultOtoA.arrivalStatus
         + _resultOtoB.arrivalStatus
         + _resultOtoC.arrivalStatus) < 2) {
        NSLog(@"[ERROR]: Calc CCF error.");
        return;
    }

    dispatch_async(_inputQueue, ^{
        stAnswers answers;
        [self estimate:&answers];
        [_delegate didCalculated:self
                     withAnswers:answers
                        countNum:num];
    });
}

- (void)newCCFWithBaseData:(float *)baseData
                   subData:(float *)subData
                    result:(stCCFResult *)result
                      name:(NSString *)name {

    NSDate *startTimeOfCCF = [NSDate date];
    NSTimeInterval since;//, temp;
    unsigned int num = _count;

    result->max = 0;
    result->indexOfMax = 0;

    unsigned int limitSample   = NextPowerOfTwo(kLimitSample);
    unsigned int bNumOfSamples = limitSample * 2;

    float *resultArray = MEM_CALLOC(bNumOfSamples, sizeof(float));

    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>prepare startCCF: %f", num, name, since);



    for (int i=kOffset; i<bNumOfSamples+kOffset; i++) {
        float tempBase = 0.0;
        float tempSub  = 0.0;
        for (int j=limitSample+kOffset; j<kRange; j++) {
            resultArray[i-kOffset] += baseData[i+j-limitSample-kOffset] * subData[j];
            tempBase += pow(baseData[i+j-limitSample-kOffset], 2);
            tempSub  += pow(subData[j], 2);
        }
        /* set result */
        resultArray[i-kOffset] /= sqrt(tempBase * tempSub);
    }

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>DONE CCF: %f", num, name, since - temp);

    /* liner prediction */
    unsigned int rNumOfSamples = bNumOfSamples * pow(2.0, kPowerNumberOfTwo);
    int bLog2n = log2(bNumOfSamples);
    int rLog2n = log2(rNumOfSamples);

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>prepare create setup: %f", num, name, since - temp);

    FFTSetup fftBaseSetup = vDSP_create_fftsetup(bLog2n, FFT_RADIX2);
    DSPSplitComplex bComplex;

    bComplex.realp = MEM_CALLOC(bNumOfSamples, sizeof(float));
    bComplex.imagp = MEM_CALLOC(bNumOfSamples, sizeof(float));

    const char *cName = [name UTF8String];
    char path[100];
    sprintf(path, "/Users/kosuke/Acoust/newCalcResult/baseCCF_%s_up%d_%d.txt", cName, (int)kPowerNumberOfTwo, num);
    FILE *baseCCF = fopen(path, "w");
    for (int i=0; i<bNumOfSamples; i++) {
        bComplex.realp[i] = resultArray[i];
        bComplex.imagp[i] = 0.0;
        fprintf(baseCCF, "%d %f\n", i, resultArray[i]);
    }
    fclose(baseCCF);

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>Done prepare setup and go fft: %f", num, name, since - temp);

    /* fft */
    vDSP_fft_zip(fftBaseSetup, &bComplex, 1, (vDSP_Length)bLog2n, FFT_FORWARD);

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@>DONE FFT: %f", num, name, since - temp);

    /* prepare result */
    FFTSetup fftResSetup = vDSP_create_fftsetup(rLog2n, FFT_RADIX2);
    DSPSplitComplex rComplex;

    rComplex.realp = MEM_CALLOC(rNumOfSamples, sizeof(float));
    rComplex.imagp = MEM_CALLOC(rNumOfSamples, sizeof(float));

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@> resSetup DONE: %f", num, name, since - temp);

    for (int i=0; i<bNumOfSamples/2; i++) {
        rComplex.realp[i] = bComplex.realp[i];
        rComplex.imagp[i] = bComplex.imagp[i];
    }
    for (int i=rNumOfSamples-(bNumOfSamples/2); i<rNumOfSamples; i++) {
        rComplex.realp[i] = bComplex.realp[i-rNumOfSamples+bNumOfSamples];
        rComplex.imagp[i] = bComplex.imagp[i-rNumOfSamples+bNumOfSamples];
    }

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@> now, IFFT START: %f", num, name, since - temp);

    /* ifft */
    vDSP_fft_zip(fftResSetup, &rComplex, 1, (vDSP_Length)rLog2n, FFT_INVERSE);

    //temp  = since;
    //since = - [startTimeOfCCF timeIntervalSinceNow];
    //NSLog(@"%d<%@> IFFT DONE: %f", num, name, since - temp);

    unsigned int startOffset = (rNumOfSamples / 2) - kUpedLimitSample;
    /*
    NSLog(@"bNumOfSamples= %d", bNumOfSamples);
    NSLog(@"rNumOfSamples= %d", rNumOfSamples);
    NSLog(@"startOffset= %d", startOffset);
    NSLog(@"kUpedLimiSample= %d", kUpedLimitSample);
    NSLog(@"ccf_Range= %d", kUpedLimitSample * 2);
     */

    char resPath[100];
    sprintf(resPath, "/Users/kosuke/Acoust/newCalcResult/resCCF_%s_up%d_%d.txt", cName, (unsigned int)kPowerNumberOfTwo, num);
    FILE *resCCF = fopen(resPath, "w");
    for (int i=startOffset; i<startOffset+kUpedLimitSample*2; i++) {
        double temp = rComplex.realp[i] / pow(2, bLog2n);
        if (result->max < temp) {
            result->max = temp;
            result->indexOfMax = i - startOffset;
        }
        fprintf(resCCF, "%d %f\n", i, temp);
    }
    fclose(resCCF);

    /* set result */
    if (result->indexOfMax <  - 1) {
        result->arrivalStatus = kIsAheadBase;
        result->arrivalSampleLag = - (kUpedLimitSample - 1 - result->indexOfMax);
        result->arrivalTimeLag = (double)result->arrivalSampleLag * kUpedPerSample;
    }
    else if ((result->indexOfMax == kUpedLimitSample)
             || (result->indexOfMax == kUpedLimitSample - 1)) {
        result->arrivalStatus    = kIsSame;
        result->arrivalSampleLag = 0;
        result->arrivalTimeLag   = 0.0;
    }
    else {
        result->arrivalStatus    = kIsAheadSub;
        result->arrivalSampleLag = - (kUpedLimitSample + 1 - result->indexOfMax);
        result->arrivalTimeLag   = (double)result->arrivalSampleLag * kUpedPerSample;
    }

    since = - [startTimeOfCCF timeIntervalSinceNow];
    NSLog(@"%d<%@> DONE CCF ALL: %f", num, name, since);

    /* memory free */
    vDSP_destroy_fftsetup(fftBaseSetup);
    vDSP_destroy_fftsetup(fftResSetup);
    free(bComplex.realp);
    free(bComplex.imagp);
    free(rComplex.realp);
    free(rComplex.imagp);
    free(resultArray);
    return;
}

//
- (void)calcWithABL:(AudioBufferList *)bufferList {
    /* まず全部周波数領域にやってからいっかつで処理パターン */
    NSDate *startTimeOfCalc = [NSDate date];
    NSTimeInterval since;
    unsigned int num = _count;

    float *dataO = (float *)bufferList->mBuffers[0].mData;
    float *dataA = (float *)bufferList->mBuffers[1].mData;
    float *dataB = (float *)bufferList->mBuffers[/*2*/0].mData;
    float *dataC = (float *)bufferList->mBuffers[/*3*/1].mData;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, queue, ^{
        [self calcGreatCCFWithBaseData:dataO
                               subData:dataA
                                result:&_resultOtoA
                                  name:@"OtoA"];
    });
    dispatch_group_async(group, queue, ^{
        [self calcGreatCCFWithBaseData:dataO
                               subData:dataB
                                result:&_resultOtoB
                                  name:@"OtoB"];
    });
    dispatch_group_async(group, queue, ^{
        [self calcGreatCCFWithBaseData:dataO
                               subData:dataC
                                result:&_resultOtoC
                                  name:@"OtoC"];
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);

    [self dumpCCFResult:&_resultOtoA withName:@"OtoA"];
    [self dumpCCFResult:&_resultOtoB withName:@"OtoB"];
    [self dumpCCFResult:&_resultOtoC withName:@"OtoC"];
    since = - [startTimeOfCalc timeIntervalSinceNow];
    NSLog(@"<%d>CCFED TIME: %f", num, since);

    /* check ccf error */
    if ((_resultOtoA.arrivalStatus
         + _resultOtoB.arrivalStatus
         + _resultOtoC.arrivalStatus) < 2) {
        NSLog(@"[ERROR]: Calc CCF error.");
        return;
    }

    dispatch_async(_inputQueue, ^{
        stAnswers ansers;
        [self estimate:&ansers];
        [_delegate didCalculated:self
                     withAnswers:ansers
                        countNum:num];
    });

}

- (void)calcGreatCCFWithBaseData:(float *)baseData
                         subData:(float *)subData
                          result:(stCCFResult *)result
                            name:(NSString *)name {

    result->max = 0;
    result->indexOfMax = 0;
    //const char *cName = [name UTF8String];

    /* prepare */
    unsigned int bNumOfSamples = self.baseNumberOfSamples;
    unsigned int rNumOfSamples = self.responseNumberOfSamples;
    int bLog2n = log2(bNumOfSamples);
    int rLog2n = log2(rNumOfSamples);

    FFTSetup fftBaseSetup = vDSP_create_fftsetup(bLog2n, FFT_RADIX2);
    FFTSetup fftSubSetup = vDSP_create_fftsetup(bLog2n, FFT_RADIX2);
    DSPSplitComplex bComplex, sComplex;

    bComplex.realp = MEM_CALLOC(bNumOfSamples, sizeof(float));
    bComplex.imagp = MEM_CALLOC(bNumOfSamples, sizeof(float));
    sComplex.realp = MEM_CALLOC(bNumOfSamples, sizeof(float));
    sComplex.imagp = MEM_CALLOC(bNumOfSamples, sizeof(float));

    for (int i=0; i<bNumOfSamples; i++) {
        bComplex.realp[i] = baseData[i+kOffset];
        bComplex.imagp[i] = 0.0;
        sComplex.realp[i] = subData[i+kOffset+kLimitSample];
        sComplex.imagp[i] = 0.0;
    }

    /* fft */
    vDSP_fft_zip(fftBaseSetup, &bComplex, 1, (vDSP_Length)bLog2n, FFT_FORWARD);
    vDSP_fft_zip(fftSubSetup, &sComplex, 1, (vDSP_Length)bLog2n, FFT_FORWARD);

    /* prepare result array */
    // TODO: memberable
    FFTSetup fftResSetup = vDSP_create_fftsetup(rLog2n, FFT_RADIX2);
    DSPSplitComplex rComplex;

    rComplex.realp = MEM_CALLOC(rNumOfSamples, sizeof(float));
    rComplex.imagp = MEM_CALLOC(rNumOfSamples, sizeof(float));

    /* cross spectral */
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, queue, ^{
        for (int i=0; i<bNumOfSamples/2; i++) {
            rComplex.realp[i] = (bComplex.realp[i] * sComplex.realp[i]
                                 + bComplex.imagp[i] * sComplex.imagp[i]);
            rComplex.imagp[i] = (bComplex.imagp[i] * sComplex.realp[i]
                                 - bComplex.realp[i] * sComplex.imagp[i]);
        }
    });
    unsigned int offset = bNumOfSamples - rNumOfSamples;
    dispatch_group_async(group, queue, ^{
        for (int i=rNumOfSamples-(bNumOfSamples/2); i<rNumOfSamples; i++) {
            rComplex.realp[i] = (bComplex.realp[i+offset] * sComplex.realp[i+offset]
                                 + bComplex.imagp[i+offset] * sComplex.imagp[i+offset]);
            rComplex.imagp[i] = (bComplex.imagp[i+offset] * sComplex.realp[i+offset]
                                 - bComplex.realp[i+offset] * sComplex.imagp[i+offset]);
        }
    });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);

    /* IFFT */
    vDSP_fft_zip(fftResSetup, &rComplex, 1, (vDSP_Length)rLog2n, FFT_INVERSE);
    //char path[100];
    //sprintf(path, "/Users/kosuke/Desktop/great/greatCCF_%s_up4_%d.txt", cName, _count);
    //FILE *ccf = fopen(path, "w");
    for (int i=0; i<kUpedLimitSample*2; i++) {
        double temp = rComplex.realp[i];// / pow(2.0, bLog2n);
        //fprintf(ccf, "%d %f\n", i, temp);
        if (result->max < temp) {
            result->max = temp;
            result->indexOfMax = i;
        }
    }
    //fclose(ccf);

    /* set result */
    if (result->indexOfMax < kUpedLimitSample - 1) {
        result->arrivalStatus = kIsAheadBase;
        result->arrivalSampleLag = - (kUpedLimitSample - 1 - result->indexOfMax);
        result->arrivalTimeLag = (double)result->arrivalSampleLag * kUpedPerSample;
    }
    else if ((result->indexOfMax == kUpedLimitSample) || (result->indexOfMax == kUpedLimitSample - 1)) {
        result->arrivalStatus    = kIsSame;
        result->arrivalSampleLag = 0;
        result->arrivalTimeLag   = 0.0;
    }
    else {
        result->arrivalStatus    = kIsAheadSub;
        result->arrivalSampleLag = - (kUpedLimitSample + 1 - result->indexOfMax);
        result->arrivalTimeLag   = (double)result->arrivalSampleLag * kUpedPerSample;
    }

    /* memory free */
    vDSP_destroy_fftsetup(fftBaseSetup);
    vDSP_destroy_fftsetup(fftSubSetup);
    vDSP_destroy_fftsetup(fftResSetup);
    free(bComplex.realp);
    free(bComplex.imagp);
    free(sComplex.realp);
    free(sComplex.imagp);
    free(rComplex.realp);
    free(rComplex.imagp);
    return;
}



#pragma mark - calculation CORE

- (void)calculateWithABL:(AudioBufferList *)bufferList {

    unsigned int num = _count;
    float *dataO = (float *)bufferList->mBuffers[0].mData;
    float *dataA = (float *)bufferList->mBuffers[1].mData;
    float *dataB = (float *)bufferList->mBuffers[2].mData;
    float *dataC = (float *)bufferList->mBuffers[3].mData;

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

    unsigned int sampleRate = kSamplePer * pow(2.0, kPowerNumberOfTwo);
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

        stAnswers answers;
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
                 result:(stCCFResult *)result
                   name:(NSString *)name {

    result->max = 0;
    double *resultArray = MEM_CALLOC(kUpedLimitSample * 2, sizeof(double));
    const char *cName = [name UTF8String];
    char path[100];
    sprintf(path, "/Users/kosuke/Desktop/EstimaResult/ccf/ccf%s_%d.txt", cName, _count);
    FILE *fp = fopen(path, "w");
    for (int i=kOffset; i<kUpedLimitSample*2+kOffset; i++) {
        double tempBase = 0.0;
        double tempSub  = 0.0;
        for (int j=kUpedLimitSample+kOffset; j<kRange; j++) {
            resultArray[i-kOffset] += baseData[i+j-kUpedLimitSample-kOffset] * subData[j];
            tempBase += pow(baseData[i+j-kUpedLimitSample-kOffset], 2);
            tempSub  += pow(subData[j], 2);
        }

        resultArray[i-kOffset] /= sqrt(tempBase * tempSub);
        fprintf(fp, "%d %f\n", i - kOffset, resultArray[i-kOffset]);
        if (result->max < resultArray[i-kOffset]) {
            result->max = resultArray[i-kOffset];
            result->indexOfMax = i - kOffset;
        }
    }
    fclose(fp);
    if (result->indexOfMax < kUpedLimitSample - 1) {
        result->arrivalStatus    = kIsAheadBase;
        result->arrivalSampleLag =  (kUpedLimitSample -1 - result->indexOfMax);
        result->arrivalTimeLag   = (double)result->arrivalSampleLag * kUpedPerSample;
    }
    else if ((result->indexOfMax == kUpedLimitSample)
             || (result->indexOfMax == kUpedLimitSample - 1)) {
        result->arrivalStatus    = kIsSame;
        result->arrivalSampleLag = 0;
        result->arrivalTimeLag   = 0.0;
    }
    else {
        result->arrivalStatus    = kIsAheadSub;
        result->arrivalSampleLag =  (kUpedLimitSample + 1 - result->indexOfMax);
        result->arrivalTimeLag   = (double)result->arrivalSampleLag * kUpedPerSample;
    }

    free(resultArray);
}

- (void)estimate:(stAnswers *)ans {

    int num = _count;
    double drA = kSonic * _resultOtoA.arrivalTimeLag;
    double drB = kSonic * _resultOtoB.arrivalTimeLag;
    double drC = kSonic * _resultOtoC.arrivalTimeLag;
    /* powered */
    double p2_drA  = pow(drA, 2.0);
    double p2_drB  = pow(drB, 2.0);
    double p2_drC  = pow(drC, 2.0);
    double p2_dist = pow(kMicDist, 2.0);

    /* put BIG A, B, C to tmpOne, tmpTwo, tmpThree */
    double tmpOne   = 4.0 * (+ (3.0 * (+ p2_drA
                                       + p2_drB
                                       + p2_drC)
                                )
                             - 2.0 * (+ (drA * drB)
                                      + (drA * drC)
                                      + (drB * drC)
                                      + p2_dist)
                             );

    double tmpTwo   = 4.0 * (- 3.0 * (+ pow(drA, 3.0)
                                      + pow(drB, 3.0)
                                      + pow(drC, 3.0)
                                      )
                             + (p2_drA * (drB + drC))
                             + (p2_drB * (drA + drC))
                             + (p2_drC * (drA + drB))
                             + (p2_dist * (drA + drB + drC))
                             );

    double tmpThree = 1.0 * (+ (3.0 * (+ pow(kMicDist, 4.0)
                                       + pow(drA, 4.0)
                                       + pow(drB, 4.0)
                                       + pow(drC, 4.0)
                                       )
                                )
                             - ((2.0 * p2_dist) * (p2_drA + p2_drB + p2_drC))
                             - 2.0 * (+ (p2_drA * p2_drB)
                                      + (p2_drC * (p2_drA + p2_drB)
                                         )
                                      )
                             );
    double rO;
    if (tmpOne == 0.0) {
        rO = - 1.0 * (tmpThree / tmpTwo);
    }
    else {
        rO = - 1.0 * (tmpTwo / (2.0 * tmpOne))
             + (sqrt(pow(tmpTwo, 2.0)
                     - (4.0 * tmpOne * tmpThree)
                     )
                / fabs(2.0 * tmpOne));
//        rO = - 1 * (tmpTwo / (2 * tmpOne))
//        - (sqrt(pow(tmpTwo, 2)
//                - (4 * tmpOne * tmpThree)
//                )
//           / (2 * tmpOne));
    }
    NSLog(@"%d[RESULT]: tA = %f", num, tmpOne);
    NSLog(@"%d[RESULT]: rO = %f", num, rO);
    if (isnan(rO)) {
        NSLog(@"tA: %f, tB: %f, tC: %f", tmpOne, tmpTwo, tmpThree);
        NSLog(@"b^2 - 4ac: %f", pow(tmpTwo, 2.0) - (4.0 * tmpOne * tmpThree));
        return;
    }
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

    NSLog(@"%d[RESULT]: X  = %f", num, ans->x);
    NSLog(@"%d[RESULT]: Y  = %f", num, ans->y);
    NSLog(@"%d[RESULT]: Z  = %f", num, ans->z);

}

#pragma mark - dump methods

- (void)dumpCCFResult:(stCCFResult *)result withName:(NSString *)name {
    NSLog(@"-------- DUMP %@ START (%d) --------", name, _count);
    NSLog(@"<%@>index: %d", name, result->indexOfMax);
    NSLog(@"<%@>max  : %f", name, result->max);
    if (result->arrivalStatus == kIsAheadSub) {
        NSLog(@"<%@>Sub is Arrival earlier than Base", name);
    }
    else if (result->arrivalStatus == kIsSame) {
        NSLog(@"<%@>Arrival time is Same", name);
    }
    else if (result->arrivalStatus == kIsAheadBase) {
        NSLog(@"<%@>Base is Arrival earlier than Sub", name);
    }
    NSLog(@"<%@>The SAMPLE LAG is %d sample", name, result->arrivalSampleLag);
    NSLog(@"<%@>The TIME LAG is %.12f second", name, result->arrivalTimeLag);
    NSLog(@"[DUMP %@ END (%d)]", name, _count);
    printf("\n");
}

@end
