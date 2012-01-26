//
//  ReslutOpenGLView.h
//  Estima
//
//  Created by kosuke nakamura on 12/01/04.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glu.h>
#import <GLUT/GLUT.h>
#import "Utils.h"

#define kResultCount 25

typedef struct {
    double positionX;
    double positionY;
    double positionZ;
    double viewX;
    double viewY;
    double viewZ;
    double upVectorX;
    double upVectorY;
    double upVectorZ;
} stLookAtParams;

@interface ResultOpenGLView : NSOpenGLView {

    BOOL _isPrevMode;

    double *_resultX;
    double *_resultY;
    double *_resultZ;
    
    double _resultScale;
    double _resultSolidSize;
    double _border;
    double _ortho;
    stLookAtParams _lookAtParams;

    unsigned int _countNumber;
}

@property BOOL isPrevMode;
@property(readonly) double resultScale;
@property(readonly) double resultSolidSize;
@property(readonly) double border;
@property(readonly) double ortho;
@property(readonly) stLookAtParams lookAtParams;
@property(readonly) double *resultX;
@property(readonly) double *resultY;
@property(readonly) double *resultZ;
@property(readonly) unsigned int countNumber;

- (void)reshape;
- (void)drawMic:(double)dist;
- (void)drawResultAtIndex:(unsigned int)num;
- (void)drawRect:(NSRect)dirtyRect;
- (void)setResult:(double)ansX :(double)ansY :(double)ansZ :(unsigned int)num;
- (void)rotateResults;

@end
