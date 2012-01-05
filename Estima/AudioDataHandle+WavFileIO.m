//
//  AudioDataHandle+WavFileIO.m
//  ClassTestProject
//
//  Created by kosuke nakamura on 11/12/19.
//  Copyright (c) 2011年 kosuke. All rights reserved.
//

#import "AudioDataHandle.h"


@implementation AudioDataHandle (WavFileIO)

- (void)defineIsWav {
    _isWav = YES;
    _isData = NO;
}

- (id)initWithFile:(NSString *)fFilePath {
    self =  [super init];
    if (self) {
        FILE         *pWavFile;
        sWavHeader   wavHdr;
        unsigned int offset;
        char         dataChunkID[4];
        unsigned int dataSize;
        
        // file open
        pWavFile = fopen((char *)[fFilePath UTF8String], "rb");
        if (pWavFile == NULL) {
            NSLog(@"[ERROR]: Can't open the file.");
            return nil;
        }
        
        // read to structure
        fread(&wavHdr, sizeof(wavHdr), 1, pWavFile);

        // 'RIFF' check
        if (memcmp(&wavHdr.riffChunkID, "RIFF", 4)) {
            NSLog(@"[ERROR]: This file is NOT 'RIFF' file.");
            fclose(pWavFile);
            return nil;
        }
        // 'WAVE' check
        if (memcmp(&wavHdr.riffFormatType, "WAVE", 4)) {
            NSLog(@"[ERROR]: This file is NOT 'WAVE' file.");
            fclose(pWavFile);
            return nil;
        }
        // 'fmt '
        if (memcmp(&wavHdr.fmtChunkID, "fmt ", 4)) {
            NSLog(@"[ERROR]: This file is NOT 'fmt ' type file.");
            fclose(pWavFile);
            return nil;
        }
        
        // set offset (default 36)
        offset = (int)ftell(pWavFile);
        
        // search data start
        BOOL counter = YES;
        while (counter) {
            fread(&dataChunkID, sizeof(dataChunkID), 1, pWavFile);
            if (memcmp(&dataChunkID, "data", 4)) {
                
                // set offset next byte point
                fseek(pWavFile, -3, SEEK_CUR);
                offset++;
                
                // error
                if (offset > wavHdr.riffChunkSize) {
                    NSLog(@"[ERROR]: NOT FOUND 'data' chunk.");
                    fclose(pWavFile);
                    return nil;
                }
            }
            else {
                counter = NO;
            }
        }
        // get wave size
        fread(&dataSize, sizeof(dataSize), 1, pWavFile);
        
        // init property
        if (!wavHdr.nBlockAlign) {
            NSLog(@"[ERROR]: failed file reading.");
            return nil;
        }
        self = [self initWithNumOfSamples:(dataSize / wavHdr.nBlockAlign)
                            numOfChannels:wavHdr.nChannels
                            samplesPerSec:wavHdr.nSamplesPerSec
                            bitsPerSample:wavHdr.wBitsPerSample];
        
        // scan data(limit 2ch)
        void *buf;
        unsigned int bytesPerSample = self.bytesPerSample;
        switch (_bitsPerSample) {
            case 8:
                SET_DATA_FROM_FILE(char);
                _dataType = kIsChar;
                break;
                
            case 16:
                SET_DATA_FROM_FILE(short);
                _dataType = kIsShort;
                break;
                
            case 32:
                // ieee float
                if (wavHdr.wFormatTag == 3) {
                    SET_DATA_FROM_FILE(float);
                    _dataType = kIsFloat;
                }
                // 32bit int (int supported only from file)
                else if (wavHdr.wFormatTag == 1) {
                    SET_DATA_FROM_FILE(int);
                    _dataType = kIsInt;
                }
                else {
                    NSLog(@"[ERROR]: This format is unsupported.");
                    fclose(pWavFile);
                    return nil;
                }
                break;
                
            default:
                NSLog(@"[ERROR]: This handle can not open this bit rate.");
                fclose(pWavFile);
                return nil;
                break;
        }
        fclose(pWavFile);
        
        _meta = &wavHdr;
        [self defineIsWav];
        [self internalize];
    }
    return self;
}
    
- (void)writeToWavFile:(NSString *)tFilePath {
    
    // validation
    if (!self.bytesPerSample) {
        NSLog(@"[ERROR]: Call initialize method.");
        return;
    }
    if (_numberOfChannels > 2) {
        NSLog(@"[ERROR]: this method can't write more than 2ch.");
        return;
    }
    if (_bitsPerSample == 64) {
        NSLog(@"[ERROR]: this method can't write 64bit wav.");
        return;
    }
    if (!_isInternalized) {
        NSLog(@"[ERROR]: auto internalize done.");
        [self internalize];
    }
    
    // open
    FILE *pWavFile;
    pWavFile = fopen([tFilePath UTF8String], "wb");
    if (pWavFile == NULL) {
        printf("[ERROR]: Coudn't open the file\n");
        return;
    }
    
    sWavHeader   wavHdr;
    char         dataChunkID[4];
    
    strncpy(wavHdr.riffChunkID,    "RIFF", 4);
    strncpy(wavHdr.riffFormatType, "WAVE", 4);
    strncpy(wavHdr.fmtChunkID,     "fmt ", 4);
    strncpy(dataChunkID,           "data", 4);
    wavHdr.fmtChunkSize    = 16;
    wavHdr.nChannels       = _numberOfChannels;
    wavHdr.nSamplesPerSec  = _samplesPerSec;
    wavHdr.wBitsPerSample  = _bitsPerSample;
    wavHdr.nBlockAlign     = _numberOfChannels * self.bytesPerSample;
    wavHdr.nAvgBytesPerSec = _samplesPerSec * wavHdr.nBlockAlign;
    wavHdr.riffChunkSize   = _numberOfSamples * wavHdr.nBlockAlign + sizeof(wavHdr) - 8;
    unsigned int dataSize  = wavHdr.nBlockAlign * _numberOfSamples;

    switch (_dataType) {
        case kIsFloat:
            wavHdr.wFormatTag = 3;
            break;
            
        default:
            wavHdr.wFormatTag = 1;
            break;
    }

    // write header to file
    fwrite(&wavHdr, sizeof(wavHdr), 1, pWavFile);
    fwrite(&dataChunkID, sizeof(dataChunkID), 1, pWavFile);
    fwrite(&dataSize, sizeof(dataSize), 1, pWavFile);

    // write data to file
    double dataBuf;
    double var;
    double limit = self.bufTypeLimit;
    switch (_dataType) {
        case kIsChar:
            var = 0.5;   // for round off
            WRITE_WAVDATA(char, var);
            break;
            
        case kIsShort:
            var = 0.5;
            WRITE_WAVDATA(short, var);
            break;
            
        case kIsInt:
            var = 0.5;
            WRITE_WAVDATA(int, var);
            break;
            
        case kIsFloat:
            var = 0.0;
            WRITE_WAVDATA(float, var);
            break;
            
        default:
            NSLog(@"[ERROR]");
            fclose(pWavFile);
            return;
    }
    fclose(pWavFile);
    NSLog(@"writeToFile may be SUCCEED.");
}

- (void)dumpHeader {
    // TODO: 
    return;
    if (!_isWav) {
        NSLog(@"[ERROR]: This data is NOT WAV.");
        return;
    }
    if (_meta == NULL) {
        NSLog(@"[ERROR]: NOT FOUND meta.");
        return;
    }
    
    sWavHeader *hdr = (sWavHeader *)_meta;
    NSLog(@"----- HEADER INFO -----");
    NSLog(@"allSize: %d", hdr->riffChunkSize + 8);
    NSLog(@"riffChunkID: %c%c%c%c",
          hdr->riffChunkID[0], hdr->riffChunkID[1],
          hdr->riffChunkID[2], hdr->riffChunkID[3]);
    NSLog(@"riffChunkSize: %d", hdr->riffChunkSize);
    NSLog(@"riffFormatType: %c%c%c%c",
          hdr->riffFormatType[0], hdr->riffFormatType[1],
          hdr->riffFormatType[2], hdr->riffFormatType[3]);
    NSLog(@"fmtChunkID: %c%c%c%c",
          hdr->fmtChunkID[0], hdr->fmtChunkID[1],
          hdr->fmtChunkID[2], hdr->fmtChunkID[3]);
    NSLog(@"fmtChunkSize: %d", hdr->fmtChunkSize);
    NSLog(@"wFormatTag: %d", hdr->wFormatTag);
    NSLog(@"nChannels: %d", hdr->nChannels);
    NSLog(@"nSamplesPerSec: %d", hdr->nSamplesPerSec);
    NSLog(@"nAvgBytesPerSec: %d", hdr->nAvgBytesPerSec);
    NSLog(@"nBlockAlign: %d", hdr->nBlockAlign);
    NSLog(@"wBitsPerSample %d", hdr->wBitsPerSample);
    NSLog(@" ");
}
@end
