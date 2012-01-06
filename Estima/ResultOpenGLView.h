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


@interface ResultOpenGLView : NSOpenGLView {
    double _resultX;
    double _resultY;
    double _resultZ;
    
    double _previousX;
    double _previousY;
    double _previousZ;
}

- (void)prepareOpenGL;
- (void)awakeFromNib;
- (void)reshape;
- (void)drawRect:(NSRect)dirtyRect;
- (void)dealloc;
- (void)setResult:(double)ansX :(double)ansY :(double)ansZ;

@end
