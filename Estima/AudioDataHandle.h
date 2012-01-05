//
//  AudioDataHandle.h
//  ClassTestProject
//
//  Created by kosuke nakamura on 11/12/18.
//  Copyright (c) 2011年 kosuke. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Utils.h"
#import "string.h"
#import "stdlib.h"


#define PREPARE_SET(type, temp)                       \
    returnDatas = MEM_CALLOC(num, sizeof(type **));   \
    type **temp = (type **)returnDatas;               \
    temp[0] = (type *)firstData;                      \
    for (int i=1; i<num; i++) {                       \
        temp[i] = va_arg(argList, type *);            \
    }
#define SET_DATA(type)                                         \
    for (int i=0; i<_numberOfChannels; i++) {                  \
        for (int j=0; j<_numberOfSamples; j++) {               \
             _datas[i][j] = (double)((type **)inData)[i][j];   \
        }                                                      \
    }
#define SET_DATA_FROM_FILE(type)                         \
    for (int i=0; i<_numberOfSamples; i++) {             \
        for (int j=0; j<_numberOfChannels; j++) {        \
            fread(&buf, bytesPerSample, 1 , pWavFile);   \
            _datas[j][i] = (double)*(type *)&buf;        \
        }                                                \
    }
#define WRITE_WAVDATA(type, var)                          \
    for (int i=0; i<_numberOfSamples; i++) {              \
        for (int j=0; j<_numberOfChannels; j++) {         \
            dataBuf = _datas[j][i] * limit;               \
            type wData = (type)(dataBuf + var);           \
            fwrite(&wData, sizeof(wData), 1, pWavFile);   \
        }                                                 \
    }

typedef enum {
    kIsChar   = 80,
    kIsShort  = 160,
    kIsInt    = 320,
    kIsFloat  = 321,
    kIsDouble = 640,
} eDataTypes;


#pragma mark - Start basic

@interface AudioDataHandle : NSObject {

@private
    unsigned short _numberOfChannels;
    unsigned short _bitsPerSample;
    unsigned int   _samplesPerSec;
    unsigned int   _numberOfSamples;
    double         **_datas;
    eDataTypes     _dataType;
    
    BOOL           _isData;
    BOOL           _isWav;
    BOOL           _isInternalized;
    void           *_meta;
}

@property(readonly) unsigned short numberOfChannels;
@property(readonly) unsigned short bitsPerSample;
@property(readonly) unsigned int   samplesPerSec;
@property(readonly) unsigned int   numberOfSamples;
@property(readonly) eDataTypes     dataType;

@property(readonly) unsigned int   bytesPerSample;
@property(readonly) double         bufTypeLimit;

@property(readonly) BOOL           isData;
@property(readonly) BOOL           isWav;
@property(readonly) BOOL           isInternalized;
@property(readonly) void           *meta;

// flag
- (void)defineIsData;

// class methods
+ (void **)prepareInitWithDatas:(eDataTypes)dataType
                  numOfChannels:(unsigned int)num
                      firstData:(void *)firstData, ...;
+ (void)finishInitWithDatas:(void **)initedDatas
              numOfChannels:(unsigned int)num;

// initialize
- (id)initWithNumOfSamples:(unsigned int)numOfSamples
             numOfChannels:(unsigned short)numOfChannels
             samplesPerSec:(unsigned int)samplesPerSec
             bitsPerSample:(unsigned short)bitsPerSample;
- (id)initWithDatas:(void **)inData
       numOfSamples:(unsigned int)numOfSamples
      numOfChannels:(unsigned short)numOfChannels
      samplesPerSec:(unsigned int)samplesPerSec
           dataType:(eDataTypes)dataType;

// access
- (double *)dataWithChannel:(unsigned short)ch;
- (double)access:(unsigned short)ch
         atIndex:(unsigned int)sampleNumber;
- (void)access:(unsigned short)ch
       atIndex:(unsigned int)sampleNumber
       setData:(double)sData;

// show property
- (void)dumpInfo:(NSString *)name;
- (void)dumpDatas;

// operate methods
- (void)internalize;
- (void)unInternalize;

@end


#pragma mark - Category WavFileIO

#pragma pack(push, 1)
typedef struct {
    char           riffChunkID[4];
    unsigned int   riffChunkSize;
    char           riffFormatType[4];
    
    char           fmtChunkID[4];
    unsigned int   fmtChunkSize;
    
    unsigned short wFormatTag;
    unsigned short nChannels;
    unsigned int   nSamplesPerSec;
    unsigned int   nAvgBytesPerSec;
    unsigned short nBlockAlign;
    unsigned short wBitsPerSample;
} sWavHeader;
#pragma pop

@interface AudioDataHandle (WavFileIO)
- (void)defineIsWav;
- (id)initWithFile:(NSString *)fFilePath;
- (void)writeToWavFile:(NSString *)tFilePath;
- (void)dumpHeader;
@end
