//
//  ReslutOpenGLView.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/04.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "ResultOpenGLView.h"

@interface ResultOpenGLView (private)
- (void)drawBorders:(double)edge;
- (void)drawMic:(double)dist;
@end


@implementation ResultOpenGLView


- (void)prepareOpenGL {
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}

- (void)awakeFromNib {
    
}

- (void)drawRect:(NSRect)dirtyRect {
    glClearColor(0.7, 0.87f, 0.96f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
    
    
    // sound source position
    glPushMatrix();
    glColor4d(6.0, 0.0, 3.0, 1.0);
    glTranslated(_resultX, _resultY, _resultZ);
    glutSolidSphere(5.0, 12, 12);
	glPopMatrix();

    glBegin(GL_LINES);
    {
        glColor4d(7.0, 0.0, 3.5, 1.0);
        glVertex3d(0.0, 0.0, 0.0);
        glVertex3d(_resultX, _resultY, _resultZ);
    }
    glEnd();

    
    [self drawBorders:420.0];
    [self drawMic:(50.0 / 2)];
    
    
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
    double ortho = 420.0;
    glOrtho(-ortho, ortho, -ortho, ortho, -ortho, ortho);
    gluLookAt(-30.0, -65.0, 45.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
}

- (void)setResult:(double)ansX :(double)ansY :(double)ansZ :(unsigned int)num {
    _resultX = 10 * (ansX / 2);
    _resultY = 10 * (ansY / 2);
    _resultZ = 10 * (ansZ / 2);
    _countNumber = num;
    [self setNeedsDisplay:YES];
}

- (void) dealloc {
}

@end


@implementation ResultOpenGLView (private)

- (void)drawBorders:(double)edge
{
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
        glVertex3d(-dist / 2, (-dist * sqrt(3)) / 2, 0.0);
    }
    glEnd();
    
    //BtoO
    glBegin(GL_LINES);
    {
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(-dist / 2, (-dist * sqrt(3)) / 2, 0.0);
        glVertex3d(0.0, 0.0, 0.0);
    }
    glEnd();
    
    //OtoC
    glBegin(GL_LINES);
	{
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(0.0, 0.0, 0.0);
        glVertex3d(-dist / 2, (-dist * sqrt(3)) / 6, (-dist * sqrt(6)) / 3);
	}
	glEnd();
    
	//AtoC
	glBegin(GL_LINES);
	{
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(-dist, 0.0, 0.0);
        glVertex3d(-dist / 2, (-dist * sqrt(3)) / 6, (-dist * sqrt(6)) / 3);
	}
	glEnd();
    
	//BtoC
	glBegin(GL_LINES);
	{
        glColor4d(0.0, 0.0, 1.0, 1.0);
        glVertex3d(-dist / 2, (-dist * sqrt(3)) / 2, 0.0);
        glVertex3d(-dist / 2, (-dist * sqrt(3)) / 6, (-dist * sqrt(6)) / 3);
	}
	glEnd();
}

@end