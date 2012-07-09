//
//  ReslutOpenGLView.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/04.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "ResultOpenGLView.h"



@interface ResultOpenGLView (private)
- (void)initialize;
- (void)drawBorders:(double)edge;

@end


@implementation ResultOpenGLView

@synthesize isPrevMode = _isPrevMode;
@synthesize resultScale = _resultScale;
@synthesize resultSolidSize = _resultSolidSize;
@synthesize border = _border;
@synthesize ortho = _ortho;
@synthesize lookAtParams = _lookAtParams;
@synthesize countNumber = _countNumber;
@synthesize resultX = _resultX;
@synthesize resultY = _resultY;
@synthesize resultZ = _resultZ;


- (void)prepareOpenGL {
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

- (void)awakeFromNib {
    _resultX = MEM_CALLOC(kResultCount, sizeof(double));
    _resultY = MEM_CALLOC(kResultCount, sizeof(double));
    _resultZ = MEM_CALLOC(kResultCount, sizeof(double));
    [self initialize];
}

- (void) dealloc {
    free(_resultX);
    free(_resultY);
    free(_resultZ);
}


- (void)drawMic:(double)dist
{
    //OtoA
    glBegin(GL_LINES);
    {
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(0.0, 0.0, 0.0);
        glVertex3d(-dist, 0.0, 0.0);
    }
    glEnd();
    
    //AtoB
    glBegin(GL_LINES);
    {
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(-dist, 0.0, 0.0);
        glVertex3d(-dist / 2.0, (-dist * sqrt(3.0)) / 2.0, 0.0);
    }
    glEnd();
    
    //BtoO
    glBegin(GL_LINES);
    {
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(-dist / 2.0, (-dist * sqrt(3.0)) / 2.0, 0.0);
        glVertex3d(0.0, 0.0, 0.0);
    }
    glEnd();
    
    //OtoC
    glBegin(GL_LINES);
	{
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(0.0, 0.0, 0.0);
        glVertex3d(-dist / 2.0, (-dist * sqrt(3.0)) / 6.0, (-dist * sqrt(6.0)) / 3.0);
	}
	glEnd();
    
	//AtoC
	glBegin(GL_LINES);
	{
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(-dist, 0.0, 0.0);
        glVertex3d(-dist / 2.0, (-dist * sqrt(3.0)) / 6.0, (-dist * sqrt(6.0)) / 3.0);
	}
	glEnd();
    
	//BtoC
	glBegin(GL_LINES);
	{
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(-dist / 2.0, (-dist * sqrt(3.0)) / 2.0, 0.0);
        glVertex3d(-dist / 2.0, (-dist * sqrt(3.0)) / 6.0, (-dist * sqrt(6.0)) / 3.0);
	}
	glEnd();
}

- (void)drawResultAtIndex:(unsigned int)num {
    double transRatio;
    if (num + 1 == kResultCount) {
        transRatio = 1.0;
        glPushMatrix();
        {
            glColor4d(0.2, 0.0, 0.08, transRatio);
            glTranslated(_resultX[num], _resultY[num], _resultZ[num]);
            glutSolidSphere(_resultSolidSize, 12, 12);
        }
        glPopMatrix();
    }
    else {
        transRatio = ((double)num + 1) / (kResultCount * 2.0 + ((num + (num / 50)) / 5.0));
        glPushMatrix();
        {
            glColor4d(0.6, 0.0, 0.3, transRatio);
            glTranslated(_resultX[num], _resultY[num], _resultZ[num]);
            glutSolidSphere(_resultSolidSize-0.6, 12, 12);
        }
        glPopMatrix();
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    glClearColor(0.7, 0.87f, 0.96f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
    
    // sound source position
    for (int i=0; i<kResultCount; i++) {
        [self drawResultAtIndex:i];
    }
    glBegin(GL_LINES);
    {
        glColor4d(0.7, 0.0, 0.35, 1.0);
        glVertex3d(0.0, 0.0, 0.0);
        glVertex3d(_resultX[kResultCount-1], _resultY[kResultCount-1], _resultZ[kResultCount-1]);
    }
    glEnd();
    
    [self drawBorders:_border];
    [self drawMic:(50.0 / _resultScale)];
    
    
    NSLog(@"<%u>DRAW DONE.", _countNumber);
    NSLog(@" ");
	[[self openGLContext] flushBuffer];
}

- (void)reshape {
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    
	NSRect frame =  [self frame];
	glViewport(0, 0,
               (GLsizei)frame.size.width,
               (GLsizei)frame.size.height);

    glOrtho(-_ortho, _ortho, -_ortho, _ortho, -_ortho, _ortho);
    gluLookAt(_lookAtParams.positionX, _lookAtParams.positionY, _lookAtParams.positionZ,
              _lookAtParams.viewX, _lookAtParams.viewY, _lookAtParams.viewZ,
              _lookAtParams.upVectorX, _lookAtParams.upVectorY, _lookAtParams.upVectorZ);
}

- (void)setResult:(double)ansX :(double)ansY :(double)ansZ :(unsigned int)num {
    
    [self rotateResults];

    _resultX[kResultCount-1] = 10.0 * (ansX / _resultScale);
    _resultY[kResultCount-1] = 10.0 * (ansY / _resultScale);
    _resultZ[kResultCount-1] = 10.0 * (ansZ / _resultScale);
    _countNumber = num;
    [self setNeedsDisplay:YES];
}

- (void)rotateResults {
    for (int i=0; i<kResultCount-1; i++) {
        _resultX[i] = _resultX[i+1];
        _resultY[i] = _resultY[i+1];
        _resultZ[i] = _resultZ[i+1];
    }
    _resultX[kResultCount-2] = _resultX[kResultCount-1];
    _resultY[kResultCount-2] = _resultY[kResultCount-1];
    _resultZ[kResultCount-2] = _resultZ[kResultCount-1];
}

@end


@implementation ResultOpenGLView (private)

- (void)initialize {
    _resultScale = 1.0;
    _resultSolidSize = 4.0;
    _border = _ortho = 420.0;

    _lookAtParams.positionX = -30.0;
    _lookAtParams.positionY = -65.0;
    _lookAtParams.positionZ = 45.0;
    _lookAtParams.viewX = 0.0;
    _lookAtParams.viewY = 0.0;
    _lookAtParams.viewZ = 0.0;
    _lookAtParams.upVectorX = 0.0;
    _lookAtParams.upVectorY = 0.0;
    _lookAtParams.upVectorZ = 1.0;
}

- (void)drawBorders:(double)edge {
    //X
    glBegin(GL_LINES);
    {
        glColor4d(0.0, 0.0, 0.0, 1.0);
        glVertex3d(-edge, 0.0, 0.0);
        glColor4d(1.0, 1.0, 1.0, 1.0);
        glVertex3d(edge, 0.0, 0.0);
    }
    glEnd();
    
    //Y
    glBegin(GL_LINES);
    {
        glColor4d(0.0, 0.0, 0.0, 1.0);
        glVertex3d(0.0, -edge, 0.0);
        glColor4d(1.0, 1.0, 1.0, 1.0);
        glVertex3d(0.0, edge, 0.0);
    }
    glEnd();
    
    //Z
    glBegin(GL_LINES);
    {
        glColor4d(0.0, 0.0, 0.0, 1.0);
        glVertex3d(0.0, 0.0, -edge);
        glColor4d(1.0, 1.0, 1.0, 1.0);
        glVertex3d(0.0, 0.0, edge);
    }
    glEnd();
}
@end