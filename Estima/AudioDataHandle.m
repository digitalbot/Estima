//
//  AudioDataHandle.m
//  ClassTestProject
//
//  Created by kosuke nakamura on 11/12/18.
//  Copyright (c) 2011年 kosuke. All rights reserved.
//

#import "AudioDataHandle.h"


@implementation AudioDataHandle

@synthesize numberOfChannels = _numberOfChannels;
@synthesize bitsPerSample    = _bitsPerSample;
@synthesize samplesPerSec    = _samplesPerSec;
@synthesize numberOfSamples  = _numberOfSamples;
@synthesize dataType         = _dataType;
@synthesize isData           = _isData;
@synthesize isWav            = _isWav;
@synthesize isInternalized   = _isInternalized;
@synthesize meta             = _meta;

@dynamic bytesPerSample;
- (unsigned int)bytesPerSample {
    if (!_bitsPerSample) {
        NSLog(@"[ERROR]: 'bitsPerSample' is not initialized.");
        return 0;
    }
    return (_bitsPerSample / 8);
}
@dynamic bufTypeLimit;
- (double)bufTypeLimit {
    if (!_bitsPerSample) {
        NSLog(@"[ERROR]: 'bitsPerSample' is not initialized.");
        return 0;
    }
    double temp;
    switch (_dataType) {
        case kIsDouble:
        case kIsFloat:
            temp = 1.0;
            break;

        default:
            temp = (1 << _bitsPerSample) / 2;
            break;
    }
    return temp;
}

#pragma mark - flag

- (void)defineIsData {
    _isData = YES;
    _isWav = NO;
}


#pragma mark - class methods

+ (void **)prepareInitWithDatas:(eDataTypes)dataType
                  numOfChannels:(unsigned int)num
                      firstData:(void *)firstData, ... {

    void **returnDatas;
    va_list argList;
    va_start(argList, firstData);
    switch (dataType) {
        case kIsChar:
            PREPARE_SET(char, charDatas);
            break;

        case kIsShort:
            PREPARE_SET(short, shortDatas);
            break;

        case kIsInt:
            PREPARE_SET(int, intDatas);
            break;

        case kIsFloat:
            PREPARE_SET(float, floatDatas);
            break;

        case kIsDouble:
            PREPARE_SET(double, doubleDatas);
            break;

        default:
            NSLog(@"[ERROR]: This dataType is not known.");
            break;
    }
    va_end(argList);
    return returnDatas;
}

// CALL THIS METHOD AFTER PREPARE
+ (void)finishInitWithDatas:(void **)initedDatas
              numOfChannels:(unsigned int)num {
    for (int i=0; i<num; i++) {
        free(initedDatas[i]);
    }
    free(initedDatas);
}



#pragma mark - initialize methods

- (id)initWithNumOfSamples:(unsigned int)numOfSamples
             numOfChannels:(unsigned short)numOfChannels
             samplesPerSec:(unsigned int)samplesPerSec
             bitsPerSample:(unsigned short)bitsPerSample {

    self = [super init];
    if (self) {
        _meta = NULL;

        _numberOfSamples  = numOfSamples;
        _numberOfChannels = numOfChannels;
        _bitsPerSample    = bitsPerSample;
        _samplesPerSec    = samplesPerSec;

        _datas = MEM_CALLOC(_numberOfChannels, sizeof(double **));
        for (int i=0; i<_numberOfChannels; i++) {
            _datas[i] = MEM_CALLOC(_numberOfSamples, sizeof(double *));
        }
    }
    return self;
}

- (id)initWithDatas:(void **)inData
       numOfSamples:(unsigned int)numOfSamples
      numOfChannels:(unsigned short)numOfChannels
      samplesPerSec:(unsigned int)samplesPerSec
           dataType:(eDataTypes)dataType {

    // validation
    /*
    if (numOfChannels > (sizeof(inData) / sizeof(inData[0]))) {
        NSLog(@"[ERROR]: numOfChannels is wrong.");
        return nil;
    }
     */

    self = [self initWithNumOfSamples:numOfSamples
                        numOfChannels:numOfChannels
                        samplesPerSec:samplesPerSec
                        bitsPerSample:(unsigned short)(dataType / 10)];

    if (self) {
        switch (dataType) {
            case kIsChar:
                SET_DATA(char);
                break;

            case kIsShort:
                SET_DATA(short);
                break;

            case kIsInt:
                SET_DATA(int);
                break;

            case kIsFloat:
                SET_DATA(float);
                break;

            case kIsDouble:
                SET_DATA(double);
                break;

            default:
                NSLog(@"[ERROR]: Call other init method.");
                return nil;
        }
        _dataType = dataType;
        [self defineIsData];
        [self internalize];
    }
    return self;
}


#pragma mark - accesser methods

- (double *)dataWithChannel:(unsigned short)ch {
    if (ch >= _numberOfChannels) {
        NSLog(@"[ERROR]: argument is wrong.");
        return NULL;
    }
    return _datas[ch];
}

- (double)access:(unsigned short)ch
         atIndex:(unsigned int)sampleNumber {

    return _datas[ch][sampleNumber];
}

- (void)access:(unsigned short)ch
       atIndex:(unsigned int)sampleNumber
       setData:(double)sData {

    _datas[ch][sampleNumber] = sData;
}


#pragma mark - dump methods

- (void)dumpInfo:(NSString *)name {
    unsigned int dataSize = _numberOfSamples * _numberOfChannels * self.bytesPerSample;
    NSLog(@"-------- <INFO %@> --------", name);
    NSLog(@"channels: %d", _numberOfChannels);
    NSLog(@"numberOfSamples: %d", _numberOfSamples);
    NSLog(@"samplesPerSec: %d", _samplesPerSec);
    NSLog(@"bitsPerSample: %d", _bitsPerSample);
    NSLog(@"dataSize: %d", dataSize);
    NSLog(@" ");
}

- (void)dumpDatas {
    for (int i=0; i<_numberOfSamples; i++) {
        for (int j=0; j<_numberOfChannels; j++) {
            printf(">ch[%d]: %f ", j, _datas[j][i]);
        }
        printf("\n");
    }
}


#pragma mark - operate methods

- (void)internalize {
    // check
    double max = 0.0;
    unsigned int start = (unsigned int)(_numberOfSamples / 4);
    unsigned int end   = (unsigned int)(_numberOfSamples / 3);
    for (int i=start; i<end; i++) {
        if (max < fabs(_datas[0][i])) {
            max = fabs(_datas[0][i]);
        }
    }
    if (max <= 1.0) {
        _isInternalized = YES;
        return;
    }

    // internalize start
    double limit = self.bufTypeLimit;
    for (int i=0; i<_numberOfChannels; i++) {
        for (int j=0; j<_numberOfSamples; j++) {
            _datas[i][j] /= limit;
        }
    }
    _isInternalized = YES;
}

- (void)unInternalize {
    if (!_isInternalized) {
        NSLog(@"[ERROR]: is not internalized.");
        return;
    }
    double limit = self.bufTypeLimit;
    switch (_dataType) {
        case kIsChar:
        case kIsShort:
        case kIsInt:
            for (int i=0; i<_numberOfChannels; i++) {
                for (int j=0; j<_numberOfSamples; j++) {
                    _datas[i][j] *= limit;
                }
            }
            _isInternalized = NO;
            break;
        default:
            NSLog(@"is float or double.");
            break;
    }
}

@end
