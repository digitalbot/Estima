//
//  WaveFileHandle.h
//  Estima
//
//  Created by kosuke nakamura on 11/12/04.
//  Copyright (c) 2011年 kosuke nakamura. All rights reserved.
//

#import <Foundation/Foundation.h>

#define MONORAL (_numberOfChannels == 1)
#define STEREO (_numberOfChannels == 2)

typedef enum {
    kIsChar   = 8,
    kIsShort  = 16,
    kIsFloat  = 32,
    kIsDouble = 64,
} eDataTypes;
const double kNormalizedRatio = 0.8;

@interface WaveFileHandle : NSObject {

@private
    // datas
    double *_data;                      // data (L)
    double *_dataR;                     // data (R)

    // RIFF and WAVE chunk
    char           _fileTypeTag[4];     // 'RIFF'
    unsigned int   _sizeOfRIFF;         // File size - 8
    char           _riffTypeTag[4];     // 'WAVE'

    // fmt chunk
    char           _fmtChunkTag[4];     // 'fmt '
    unsigned short _sizeOfFMT;          // 16 (PCM)
    unsigned short _formatID;           // 1 (PCM)
    unsigned short _numberOfChannels;   // number of channel
    unsigned int   _samplesPerSec;      // sampling frequency (numberOfsamples / second)
    unsigned int   _bytesPerSec;        // speed of data (sizeOfblock * numberOfchannels)
    unsigned short _sizeOfBlock;        // block size (bitsPerSample / numberOfchannels)
    unsigned short _bitsPerSample;      // quantization bit rate (8, 16, 24, 32)

    // data chunk
    char           _dataChunkTag[4];    // 'data'
    unsigned int   _sizeOfData;         // data size
    unsigned int   _numberOfSamples;    // number of samples (apiece)
    unsigned int   _offset;             // starting position of data chunk

}

// property
@property(readonly) unsigned short numberOfChannels;
@property(readonly) unsigned int   samplesPerSec;
@property(readonly) unsigned int   bytesPerSec;
@property(readonly) unsigned short sizeOfBlock;
@property(readonly) unsigned short bitsPerSample;
@property(readonly) unsigned int   sizeOfData;
@property(readonly) unsigned int   numberOfSamples;

@property(readonly) double *datas;
@property(readonly) double *datasR;
@property(readonly) double playTime;

// initialize
- (id)initWithFile:(NSString *)fFilePath;

- (id)initWithNumberOfSamples:(unsigned int)numOfSamples
                numOfChannels:(unsigned short)ch
                samplesPerSec:(unsigned int)samplesPerSec
                bitsPerSample:(unsigned short)bitsPerSample;

- (id)initMonoWithData:(void *)data
              dataType:(eDataTypes)dataType
          numOfSamples:(unsigned int)numOfSamples
         samplesPerSec:(unsigned int)samplesPerSec;

- (id)initStereoWithData:(void *)data
               withDataR:(void *)dataR
                dataType:(eDataTypes)dataType
            numOfSamples:(unsigned int)numOfSamples
           samplesPerSec:(unsigned int)samplesPerSec;

- (id)initMonoWithNormalizedData:(double *)dData
                    numOfSamples:(unsigned int)numOfSamples
                   samplesPerSec:(unsigned int)samplesPerSec
                   bitsPerSample:(unsigned short)bitsPerSample;

- (id)initStereoWithNormalizedData:(double *)dData
                         withDataR:(double *)dDataR
                      numOfSamples:(unsigned int)numOfSamples
                     samplesPerSec:(unsigned int)samplesPerSec
                     bitsPerSample:(unsigned short)bitsPerSample;

// write to file
- (void)writeToFile:(NSString *)tFilePath;

// access to sample
- (double)access:(unsigned int)index;
- (double)accessR:(unsigned int)index;
- (void)access:(unsigned int)index setData:(double)settingData;
- (void)accessR:(unsigned int)index setData:(double)setttingData;

// add data
- (void)pushData:(void *)data
       dataType:(eDataTypes)dataType
    numOfAdding:(unsigned int)numOfAddSamples;

- (void)pushData:(void *)data
      withDataR:(void *)dataR
       dataType:(eDataTypes)dataType
    numOfAdding:(unsigned int)numOfAddSamples;

// dump
- (void)showHeader:(NSString *)name;
- (void)showSamples;

// operation
- (void)normalize;
- (void)normalizeWithGain:(double)gain;
- (void)changeNumberOfSamples:(int)numOfSamples;
- (void)monolize;
- (void)unshiftSilentSamples:(unsigned int)numOfSamples;
- (void)allClear;

@end
