//
//  WaveFileHandle.m
//  Estima
//
//  Created by kosuke nakamura on 11/12/04.
//  Copyright (c) 2011年 kosuke nakamura. All rights reserved.
//

#import "WaveFileHandle.h"
#import "math.h"
#import "string.h"
#import "stdlib.h"

@implementation WaveFileHandle

@synthesize numberOfChannels = _numberOfChannels;
@synthesize samplesPerSec    = _samplesPerSec;
@synthesize bytesPerSec      = _bytesPerSec;
@synthesize sizeOfBlock      = _sizeOfBlock;
@synthesize bitsPerSample    = _bitsPerSample;
@synthesize sizeOfData       = _sizeOfData;
@synthesize numberOfSamples  = _numberOfSamples;

@synthesize data  = _data;
@synthesize dataR = _dataR;

// get playTime
@dynamic playTime;
- (double)playTime {
    double playTimeMilliSec;

    playTimeMilliSec = (double)(_numberOfSamples / _samplesPerSec) / 1000.0;
    return playTimeMilliSec;
}

#pragma mark - initialize methods

- (id)initWithFile:(NSString *)fFilePath {

    self =  [super init];
    if (self) {
        FILE *pWavFile;

        // file open
        pWavFile = fopen((char *)[fFilePath UTF8String], "rb");
        if (pWavFile == NULL) {
            printf("[ERROR]: Can't open the file\n");
            return nil;
        }

        // 'RIFF' check
        fread(&_fileTypeTag, sizeof(_fileTypeTag), 1, pWavFile);
        if (memcmp(&_fileTypeTag, "RIFF", 4)) {
            printf("[ERROR]: This file is NOT 'RIFF' file.\n");
            fclose(pWavFile);
            return nil;
        }

        // get riff size
        fread(&_sizeOfRIFF, sizeof(_sizeOfRIFF), 1, pWavFile);

        // 'WAVE' check
        fread(&_riffTypeTag, sizeof(_riffTypeTag), 1, pWavFile);
        if (memcmp(&_riffTypeTag, "WAVE", 4)) {
            printf("[ERROR]: This file is NOT 'WAVE' file.\n");
            fclose(pWavFile);
            return nil;
        }

        // 'fmt '
        fread(&_fmtChunkTag, sizeof(_fmtChunkTag), 1, pWavFile);
        if (memcmp(&_fmtChunkTag, "fmt ", 4)) {
            printf("[ERROR]: This file is NOT 'fmt ' type file.\n");
            fclose(pWavFile);
            return nil;
        }

        // get header infometions
        fread(&_sizeOfFMT, sizeof(_sizeOfFMT), 1, pWavFile);
        fread(&_formatID, sizeof(_formatID), 1, pWavFile);
        fread(&_numberOfChannels, sizeof(_numberOfChannels), 1, pWavFile);
        fread(&_samplesPerSec, sizeof(_samplesPerSec), 1, pWavFile);
        fread(&_bytesPerSec, sizeof(_bytesPerSec), 1, pWavFile);
        fread(&_sizeOfBlock, sizeof(_sizeOfBlock), 1, pWavFile);
        fread(&_bitsPerSample, sizeof(_bitsPerSample), 1, pWavFile);

        // set offset (default 36)
        _offset = (int)ftell(pWavFile);

        // search data start
        BOOL counter = YES;
        while (counter) {
            fread(&_dataChunkTag, sizeof(_dataChunkTag), 1, pWavFile);
            if (memcmp(&_dataChunkTag, "data", 4)) {
                // set offset next byte point
                fseek(pWavFile, -3, SEEK_CUR);
                _offset++;

                // error
                if (_offset > _sizeOfRIFF) {
                    printf("[ERROR]: NOT FOUND 'data' chunk.\n");
                    fclose(pWavFile);
                    return nil;
                }
            }
            else {
                counter = NO;
            }
        }

        // get wave size
        fread(&_sizeOfData, sizeof(_sizeOfData), 1, pWavFile);

        // samples apiece
        _numberOfSamples = _sizeOfData / (2 * _numberOfChannels);

        // get wave data
        _data = calloc(_numberOfSamples, sizeof(double));
        if (STEREO) {
            _dataR = calloc(_numberOfSamples, sizeof(double));
        }
        // cast
        double buf;
        for (int i=0; i<_numberOfSamples; i++) {
            fread(&buf, _bitsPerSample, 1, pWavFile);
            _data[i] = buf;
            if (STEREO) {
                fread(&buf, _bitsPerSample, 1, pWavFile);
                _dataR[i] = buf;
            }
        }
        fclose(pWavFile);
        // this handle contain normalized data <-1.0 ~ 1.0>
        [self normalize];
    }
    return self;
}


- (id)initWithNumberOfSamples:(unsigned int)numOfSamples
                numOfChannels:(unsigned short)ch
                samplesPerSec:(unsigned int)samplesPerSec
                bitsPerSample:(unsigned short)bitsPerSample {

    self = [super init];
    if (self) {
        // default header
        char fileTypeTag[4]  = { 'R', 'I', 'F', 'F' };
        char riffTypeTag[4]  = { 'W', 'A', 'V', 'E' };
        char fmtChunkTag[4]  = { 'f', 'm', 't', ' ' };
        char dataChunkTag[4] = { 'd', 'a', 't', 'a' };
        strcpy(_fileTypeTag,  fileTypeTag);
        strcpy(_riffTypeTag,  riffTypeTag);
        strcpy(_fmtChunkTag,  fmtChunkTag);
        strcpy(_dataChunkTag, dataChunkTag);

        _offset           = 36;
        _sizeOfFMT        = 16;
        _formatID         = 1;
        _numberOfChannels = ch;
        _numberOfSamples  = numOfSamples;
        _bitsPerSample    = bitsPerSample;
        _samplesPerSec    = samplesPerSec;
        _sizeOfBlock      = _numberOfChannels * sizeof(_bitsPerSample);
        _sizeOfRIFF       = _numberOfSamples * _sizeOfBlock + _offset;
        _bytesPerSec      = _samplesPerSec * _sizeOfBlock;
        _sizeOfData       = _sizeOfBlock * _numberOfSamples;

        _data = calloc(_numberOfSamples, sizeof(double));
        if (STEREO) {
            _dataR = calloc(_numberOfSamples, sizeof(double));
        }
    }
    return self;
}


- (id)initMonoWithData:(void *)inData
              dataType:(eDataTypes)dataType
          numOfSamples:(unsigned int)numOfSamples
         samplesPerSec:(unsigned int)samplesPerSec {

    self = [self initWithNumberOfSamples:numOfSamples
                           numOfChannels:1
                           samplesPerSec:samplesPerSec
                           bitsPerSample:(unsigned short)dataType];
    if (self) {
        switch (dataType) {
        case kIsChar:
            for (int i=0; i<numOfSamples; i++) {
                _data[i] = (double)*((char *)inData + i);
            }
            break;

        case kIsShort:
            for (int i=0; i<numOfSamples; i++) {
                _data[i] = (double)*((short *)inData + i);
            }
            break;

        case kIsFloat:
            for (int i=0; i<numOfSamples; i++) {
                _data[i] = (double)*((float *)inData + i);
            }
            break;

        case kIsDouble:
            printf("[ERROR]: Call other init method.\n");
            return nil;
        }
        [self normalize];
    }
    return self;
}

- (id)initStereoWithData:(void *)inData
               withDataR:(void *)inDataR
                dataType:(eDataTypes)dataType
            numOfSamples:(unsigned int)numOfSamples
           samplesPerSec:(unsigned int)samplesPerSec {

    self = [self initWithNumberOfSamples:numOfSamples
                           numOfChannels:2
                           samplesPerSec:samplesPerSec
                           bitsPerSample:(unsigned int)dataType];
    if (self) {
        switch (dataType) {
        case kIsChar:
            for (int i=0; i<numOfSamples; i++) {
                _data[i]  = (double)*((char *)inData + i);
                _dataR[i] = (double)*((char *)inDataR + i);
            }
            break;

        case kIsShort:
            for (int i=0; i<numOfSamples; i++) {
                _data[i]  = (double)*((short *)inData + i);
                _dataR[i] = (double)*((short *)inDataR + i);
            }
            break;

        case kIsFloat:
            for (int i=0; i<numOfSamples; i++) {
                _data[i]  = (double)*((float *)inData + i);
                _dataR[i] = (double)*((float *)inDataR + i);
            }
            break;

        case kIsDouble:
            printf("[ERROR]: Call other init method.\n");
            return nil;
        }
        [self normalize];
    }
    return self;
}

// init from WaveFileHandle's data
- (id)initMonoWithNormalizedData:(double *)dData
                    numOfSamples:(unsigned int)numOfSamples
                   samplesPerSec:(unsigned int)samplesPerSec
                   bitsPerSample:(unsigned short)bitsPerSample {

    self = [self initWithNumberOfSamples:numOfSamples
                           numOfChannels:1
                           samplesPerSec:samplesPerSec
                           bitsPerSample:bitsPerSample];

    if (self) {
        for (int i=0; i<numOfSamples; i++) {
            if (dData[i] < -1.0 && 1.0 < dData[i]) {
                printf("[ERROR]: These data are NOT normalized.\n");
                return nil;
            }
            _data[i] = dData[i];
        }
    }
    return self;
}

- (id)initStereoWithNormalizedData:(double *)dData
                         withDataR:(double *)dDataR
                      numOfSamples:(unsigned int)numOfSamples
                     samplesPerSec:(unsigned int)samplesPerSec
                     bitsPerSample:(unsigned short)bitsPerSample {

    self = [self initWithNumberOfSamples:numOfSamples
                           numOfChannels:2
                           samplesPerSec:samplesPerSec
                           bitsPerSample:bitsPerSample];

    if (self) {
        for (int i=0; i<numOfSamples; i++) {
            if (dData[i] < -1.0 && 1.0 < dData[i]) {
                printf("[ERROR]: These data are NOT normalized.\n");
                return nil;
            }
            if (dDataR[i] < -1.0 && 1.0 < dDataR[i]) {
                printf("[ERROR]: These data are NOT normalized.\n");
                return nil;
            }
            _data[i]  = dData[i];
            _dataR[i] = dDataR[i];
        }
    }
    return self;
}

- (void)dealloc {
    free(_data);
    if (STEREO) {
        free(_dataR);
    }
}


#pragma mark - operation methods

- (void)writeToFile:(NSString *)tFilePath {
    // open
    FILE *pWavFile;
    pWavFile = fopen([tFilePath UTF8String], "wb");
    if (pWavFile == NULL) {
        printf("[ERROR]: Can't open the file\n");
        return;
    }

    // to header
    fwrite(&_fileTypeTag, sizeof(_fileTypeTag), 1, pWavFile);
    fwrite(&_sizeOfRIFF, sizeof(_sizeOfRIFF), 1, pWavFile);
    fwrite(&_riffTypeTag, sizeof(_riffTypeTag), 1, pWavFile);
    fwrite(&_fmtChunkTag, sizeof(_fmtChunkTag), 1, pWavFile);
    fwrite(&_sizeOfFMT, sizeof(_sizeOfFMT), 1, pWavFile);
    fwrite(&_formatID, sizeof(_formatID), 1, pWavFile);
    fwrite(&_numberOfChannels, sizeof(_numberOfChannels), 1, pWavFile);
    fwrite(&_samplesPerSec, sizeof(_samplesPerSec), 1, pWavFile);
    fwrite(&_bytesPerSec, sizeof(_bytesPerSec), 1, pWavFile);
    fwrite(&_sizeOfBlock, sizeof(_sizeOfBlock), 1, pWavFile);
    fwrite(&_bitsPerSample, sizeof(_bitsPerSample), 1, pWavFile);
    fwrite(&_dataChunkTag, sizeof(_dataChunkTag), 1, pWavFile);
    fwrite(&_sizeOfData, sizeof(_sizeOfData), 1, pWavFile);

    // data
    double dataBuf;
    double bufAbsLimit = (1 << (8 * _bitsPerSample)) / 2;
    if (MONORAL) {
        switch (_bitsPerSample) {
        case 8:
            for (int i=0; i<_numberOfSamples; i++) {
                dataBuf = _data[i] * bufAbsLimit;
                char writingData = (char)(dataBuf + 0.5);
                fwrite(&writingData, sizeof(writingData), 1, pWavFile);
            }
            break;

        case 16:
            for (int i=0; i<_numberOfSamples; i++) {
                dataBuf = _data[i] * bufAbsLimit;
                short writingData = (short)(dataBuf + 0.5);
                fwrite(&writingData, sizeof(writingData), 1, pWavFile);
            }
            break;

        case 32:
            for (int i=0; i<_numberOfSamples; i++) {
                dataBuf = _data[i] * bufAbsLimit;
                float writingData = (float)dataBuf;
                fwrite(&writingData, sizeof(writingData), 1, pWavFile);
            }
            break;

        default:
            printf("[ERROR]: can't write this quantization bit rate.\n");
            fclose(pWavFile);
            return;
        }
    }
    else if (STEREO) {
        switch (_bitsPerSample) {
        case 8:
            for (int i=0; i<_numberOfSamples; i++) {
                char writingData;
                // L
                dataBuf = _data[i] * bufAbsLimit;
                writingData = (char)(dataBuf + 0.5);
                fwrite(&writingData, sizeof(writingData), 1, pWavFile);
                // R
                dataBuf = _dataR[i] * bufAbsLimit;
                writingData = (char)(dataBuf + 0.5);
                fwrite(&writingData, sizeof(writingData), 1, pWavFile);
            }
            break;

        case 16:
            for (int i=0; i<_numberOfSamples; i++) {
                short writingData;
                // L
                dataBuf = _data[i] * bufAbsLimit;
                writingData = (short)(dataBuf + 0.5);
                fwrite(&writingData, sizeof(writingData), 1, pWavFile);
                // R
                dataBuf = _dataR[i] * bufAbsLimit;
                writingData = (short)(dataBuf + 0.5);
                fwrite(&writingData, sizeof(writingData), 1, pWavFile);
            }
            break;

        case 32:
            for (int i=0; i<_numberOfSamples; i++) {
                float writingData;
                // L
                dataBuf = _data[i] * bufAbsLimit;
                writingData = (float)dataBuf;
                fwrite(&writingData, sizeof(writingData), 1, pWavFile);
                // R
                dataBuf = _dataR[i] * bufAbsLimit;
                writingData = (float)dataBuf;
                fwrite(&writingData, sizeof(writingData), 1, pWavFile);
            }
            break;

        default:
            printf("[ERROR]: can't write this quantization bit rate.\n");
            fclose(pWavFile);
            return;
        }
    }
    printf("writeToFile may be success.\n");
    fclose(pWavFile);
}


// accesser methods
- (double)access:(unsigned int)index {
    return (_data[index]);
}

- (double)accessR:(unsigned int)index {
    return (_dataR[index]);
}

- (void)access:(unsigned int)index setData:(double)sData {
    _data[index] = sData;
}

- (void)accessR:(unsigned int)index setData:(double)sData {
    _dataR[index] = sData;
}

// validate for pushData method (private)
- (BOOL)validatePushData_:(void *)aData
                         :(BOOL *)isNormalized
                         :(eDataTypes)dataType
                         :(unsigned int)numOfAddSamples {

    BOOL tmp = NO;
    if (numOfAddSamples <= 0) {
        printf("[ERROR]: num of adding is must be POSITIVE INTEGER.\n");
        return NO;
    }

    if (dataType == kIsDouble) {
        for (int i=0; i<_numberOfSamples; i++) {
            // check normalized
            if (*((double *)aData + i) < -1.0 && 1.0 < *((double *)aData + i)) {
                tmp = NO;
                isNormalized = &tmp;
                return YES;
            }
        }
        tmp = YES;
        isNormalized = &tmp;
    }
    return YES;
}

- (void)pushData:(void *)aData
        dataType:(eDataTypes)dataType
     numOfAdding:(unsigned int)numOfAddSamples {

    void *dummy = NULL;
    [self pushData:aData
         withDataR:dummy
          dataType:dataType
       numOfAdding:numOfAddSamples];
}

- (void)pushData:(void *)aData
       withDataR:(void *)aDataR
        dataType:(eDataTypes)dataType
     numOfAdding:(unsigned int)numOfAddSamples {

    BOOL isNormalized = 0;
    // validation
    if(![self validatePushData_:aData :&isNormalized :dataType :numOfAddSamples]) {
        return;
    }

    // if adding is normalized, through this if block
    if (!isNormalized) {
        double bufAbsLimit = (1 << (8 * (unsigned int)dataType)) / 2;
        for (int i=0; i<_numberOfSamples; i++) {
            _data[i] *= bufAbsLimit;
            _dataR[i] *= bufAbsLimit;
        }
    }

    // realloc
    [self changeNumberOfSamples:numOfAddSamples];

    // set data
    unsigned int originLength = _numberOfSamples - numOfAddSamples;
    switch (dataType) {
        case kIsChar:
            for (int i=0; i<numOfAddSamples; i++) {
                [self access:(originLength + i)
                     setData:(double)*((char *)aData + i)];
                if (STEREO) {
                    [self accessR:(originLength + i)
                          setData:(double)*((char *)aData + i)];
                }
            }
            break;

        case kIsShort:
            for (int i=0; i<numOfAddSamples; i++) {
                [self access:(originLength + i)
                     setData:(double)*((short *)aData + i)];
                if (STEREO) {
                    [self accessR:(originLength + i)
                          setData:(double)*((short *)aData + i)];
                }
            }
            break;

        case kIsFloat:
            for (int i=0; i<numOfAddSamples; i++) {
                [self access:(originLength + i)
                     setData:(double)*((float *)aData + i)];
                if (STEREO) {
                    [self accessR:(originLength + i)
                          setData:(double)*((float *)aData + i)];
                }
            }
            break;

        case kIsDouble:
            for (int i=0; i<numOfAddSamples; i++) {
                [self access:(originLength + i)
                     setData:(double)*((double *)aData + i)];
                if (STEREO) {
                    [self accessR:(originLength + i)
                          setData:(double)*((double *)aData + i)];
                }
            }
            break;
    }
    [self normalize];
}

#pragma mark - dump methods

- (void)showHeader:(NSString *)name {
    NSLog(@"----- HEADER INFO %@ -----", name);
    NSLog(@"allSize: %d", _sizeOfRIFF + 8);
    NSLog(@"fileType: %s", _fileTypeTag);
    NSLog(@"riffSize: %d", _sizeOfRIFF);
    NSLog(@"riffType: %s", _riffTypeTag);
    NSLog(@"fmtChunkTAg : %s", _fmtChunkTag);
    NSLog(@"fmtSize: %d", _sizeOfFMT);
    NSLog(@"formatID: %d", _formatID);
	NSLog(@"channel: %d", _numberOfChannels);
	NSLog(@"samplesPerSec: %d", _samplesPerSec);
	NSLog(@"bytesPerSec: %d", _bytesPerSec);
	NSLog(@"blockSize: %d", _sizeOfBlock);
	NSLog(@"bitsPerSample: %d", _bitsPerSample);
    NSLog(@"dataChunkTag : %s", _dataChunkTag);
	NSLog(@"dataSize: %d", _sizeOfData);
	NSLog(@"offset: %d", _offset);
	NSLog(@"numberOfSamples: %d", _numberOfSamples);
}

- (void)showSamples {
    // These wave data are normalized.
    if (MONORAL) {
        for (int i=0; i<_numberOfSamples; i++) {
            printf("[%d] mono: %f\n", i, [self access:i]);
        }
    }
    else if (STEREO) {
        for (int i=0; i<_numberOfSamples; i++) {
            printf("[%d] L: %f | R: %f\n", i, [self access:i], [self accessR:i]);
        }
    }
}

#pragma mark - sample calculation methods

- (void)normalize {
    double bufAbsLimit = (1 << (8 * _bitsPerSample)) / 2;
    if (MONORAL) {
        for (int i=0; i<_numberOfSamples; i++) {
            _data[i] /= bufAbsLimit;
        }
    }
    else if (STEREO) {
        for (int i=0; i<_numberOfSamples; i++) {
            _data[i] /= bufAbsLimit;
            _dataR[i] /= bufAbsLimit;
        }
    }
}

- (void)normalizeWithGain:(double)gain {
    if (0.0 <= gain && gain <= 1.0) {
        double max = 0.0;
        double dataBuf;

        // search max
        for (int i=0; i<_numberOfSamples; i++) {
            dataBuf = fabs([self access:i]);
            if (max < dataBuf) {
                max = dataBuf;
            }
            if (STEREO) {
                dataBuf = fabs([self accessR:i]);
                if (max < dataBuf) {
                    max = dataBuf;
                }
            }
        }
        if (!max) {
            printf("[ERROR]: max == 0\n");
            return;
        }

        // normalize
        for (int i=0; i<_numberOfSamples; i++) {
            _data[i] *= (gain / max);
            if (STEREO) {
                _data[i] *= (gain / max);
                _dataR[i] *= (gain / max);
            }
        }
    }
    else if (gain == -1) {
        [self normalize];
    }
    else {
        printf("[ERROR]: gain is must be <0.0 ~ 1.0> or -1\n");
    }
}

- (void)changeNumberOfSamples:(int)numOfSamples {

    unsigned int newLastPosition = _numberOfSamples + numOfSamples;
    // realloc
    _data = realloc(_data, sizeof(double) * newLastPosition);
    if (STEREO) {
        _dataR = realloc(_dataR, sizeof(double) * newLastPosition);
    }

    // fill zero
    if (0 <= numOfSamples) {
        if (MONORAL) {
            for (int i=_numberOfChannels; i<newLastPosition; i++) {
                [self access:i setData:0.0];
            }
        }
        else if (STEREO) {
            for (int i=_numberOfChannels; i<newLastPosition; i++) {
                [self access:i setData:0.0];
                [self accessR:i setData:0.0];
            }
        }
    }

    // rewrite header
    unsigned int increasedByte = numOfSamples * _bitsPerSample * _numberOfChannels;
    _numberOfSamples += numOfSamples;
    _sizeOfData += increasedByte;
    _sizeOfRIFF += increasedByte;
}

// STEREO to MONORAL
- (void)monolize {

    if (STEREO) {
        for (int i=0; i<_numberOfSamples; i++) {
            double average = (_data[i] + _dataR[i]) / 2.0;
            _data[i] = average;
        }
        // rewrite header
        _numberOfChannels = 1;
        _sizeOfBlock = _bitsPerSample * _numberOfChannels;
        _bytesPerSec = _sizeOfBlock * _samplesPerSec;
        _sizeOfData /= 2;
        _sizeOfRIFF -= _sizeOfData;

        free(_dataR);
        _dataR = NULL;
    }
    else {
        printf("[ERROR]: this file in NOT STEREO\n");
    }
}

// add to DataHead silent samples
- (void)unshiftSilentSamples:(unsigned int)numOfSamples {

    double tmp;
    // validation for overflow
    if (_numberOfSamples - numOfSamples <= 0) {
        printf("[ERROR]: Too many.\n");
        return;
    }
    [self changeNumberOfSamples:numOfSamples];

    unsigned int originLength =  _numberOfSamples - numOfSamples;
    if (MONORAL) {
        for (int i=0; i<originLength; i++) {
            tmp = _data[originLength - i - 1];
            _data[_numberOfSamples - i - 1] = tmp;
        }
        for (int i=0; i<numOfSamples; i++) {
            _data[i] = 0.0;
        }
    }
    else if (STEREO) {
        for (int i=0; i<originLength; i++) {
            // L
            tmp = _data[originLength - i - 1];
            _data[_numberOfSamples - i - 1] = tmp;
            // R
            tmp = _dataR[originLength - i - 1];
            _dataR[_numberOfSamples - i - 1] = tmp;
        }
        for (int i=0; i<numOfSamples; i++) {
            _data[i] = 0.0;
            _dataR[i] = 0.0;
        }
    }
}

// fill all sample zero
- (void)allClear {
    if (MONORAL) {
        for (int i=0; i<_numberOfSamples; i++) {
            _data[i] = 0.0;
        }
    }
    else if (STEREO) {
        for (int i=0; i<_numberOfSamples; i++) {
            _data[i] = 0.0;
            _dataR[i] = 0.0;
        }
    }
}


@end
