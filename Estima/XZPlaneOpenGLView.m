//
//  XZPlaneOpenGLView.m
//  Estima
//
//  Created by kosuke nakamura on 12/01/26.
//  Copyright (c) 2012年 kosuke nakamura. All rights reserved.
//

#import "XZPlaneOpenGLView.h"

@implementation XZPlaneOpenGLView

- (void)initialize {
    _resultScale = 1.5;
    _resultSolidSize = 2.5;
    _border = _ortho = 200.0;
    
    _lookAtParams.positionX = 0.0;
    _lookAtParams.positionY = -18.0;
    _lookAtParams.positionZ = 0.0;
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
