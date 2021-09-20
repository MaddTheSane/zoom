//
//  ZoomUpperWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomView.h>

@class ZoomView;
@interface ZoomUpperWindow : NSObject<ZUpperWindow, NSSecureCoding> {
    __unsafe_unretained ZoomView* theView;

    int startLine, endLine;

    NSMutableArray<NSMutableAttributedString*>* lines;
    int xpos, ypos;

    NSColor* backgroundColour;
	ZStyle* inputStyle;
}

- (id) initWithZoomView: (ZoomView*) view;

- (int) length;
- (NSArray<NSMutableAttributedString*>*) lines;
- (NSColor*) backgroundColour;
- (void)     cutLines;

- (void) reformatLines;

- (void) setZoomView: (ZoomView*) view;

@end
