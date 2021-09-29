//
//  ZoomUpperWindow.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Oct 09 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomProtocol.h>

@class ZoomView;
@interface ZoomUpperWindow : NSObject<ZUpperWindow, NSSecureCoding> {
    __weak ZoomView* theView;

    int startLine, endLine;

    NSMutableArray<NSMutableAttributedString*>* lines;
    int xpos, ypos;

    NSColor* backgroundColour;
	ZStyle* inputStyle;
}

- (id) initWithZoomView: (ZoomView*) view;

@property (readonly, nonatomic) int length;
- (NSArray<NSMutableAttributedString*>*) lines;
@property (readonly, strong) NSColor *backgroundColour;
- (void)     cutLines;

- (void) reformatLines;

- (void) setZoomView: (ZoomView*) view;

@end

#import <ZoomView/ZoomView.h>
