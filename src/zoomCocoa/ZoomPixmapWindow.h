//
//  ZoomPixmapWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ZoomView.h"

@interface ZoomPixmapWindow : NSObject<ZPixmapWindow, NSCoding> {
	__unsafe_unretained ZoomView* zView;
	NSImage* pixmap;
	
	NSPoint inputPos;
	ZStyle* inputStyle;
}

// Initialisation
- (instancetype) initWithZoomView: (ZoomView*) view;
@property (assign) ZoomView* zoomView;

// Getting the pixmap
@property (readonly) NSSize size;
@property (readonly, strong) NSImage *pixmap;

// Input information
@property (readonly) NSPoint inputPos;
- (ZStyle*) inputStyle;

@end
