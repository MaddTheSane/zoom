//
//  ZoomPixmapWindow.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jun 25 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#include <tgmath.h>
#import "ZoomPixmapWindow.h"


@implementation ZoomPixmapWindow

// Initialisation
- (id) initWithZoomView: (ZoomView*) view {
	self = [super init];
	
	if (self) {
		pixmap = [[NSImage alloc] initWithSize: NSMakeSize(640, 480)];
		zView = view;
		
		inputStyle = nil;
	}
	
	return self;
}

// = Getting the pixmap =

- (NSSize) size {
	return [pixmap size];
}

- (NSImage*) pixmap {
	return pixmap;
}

// = Standard window commands =

- (oneway void) clearWithStyle: (in bycopy ZStyle*) style {
	[pixmap lockFocusFlipped:YES];
	
    NSColor* backgroundColour = style.reversed?[zView foregroundColourForStyle: style]:[zView backgroundColourForStyle: style];
	[backgroundColour set];
	NSRectFill(NSMakeRect(0, 0, [pixmap size].width, [pixmap size].height));
			   
	[pixmap unlockFocus];
}

- (oneway void) setFocus {
}

- (NSSize) sizeOfFont: (NSFont*) font {
    // Hack: require a layout manager for OS X 10.6, but we don't have the entire text system to fall back on
    NSLayoutManager* layoutManager = [[NSLayoutManager alloc] init];
    
    // Width is one 'em'
    CGFloat width = [@"M" sizeWithAttributes: [NSDictionary dictionaryWithObjectsAndKeys: NSFontAttributeName, font, nil]].width;
    
    // Height is decided by the layout manager
    CGFloat height = [layoutManager defaultLineHeightForFont: font];
    
    return NSMakeSize(width, height);
}

- (oneway void) writeString: (in bycopy NSString*) string
		   withStyle: (in bycopy ZStyle*) style {
	[pixmap lockFocusFlipped:YES];
	
	NSLog(@"Warning: should not call standard ZWindow writeString on a pixmap window");
	
	[pixmap unlockFocus];
}

// Pixmap window commands
- (void) setSize: (in NSSize) windowSize {
	if (windowSize.width < 0) {
		windowSize.width = [zView bounds].size.width;
	}
	if (windowSize.height < 0) {
		windowSize.height = [zView bounds].size.height;
	}
	
	[pixmap setSize: windowSize];
}

- (void) plotRect: (in NSRect) rect
		withStyle: (in bycopy ZStyle*) style {
	[pixmap lockFocusFlipped:YES];
	
    NSColor* foregroundColour = [zView foregroundColourForStyle: style];
	[foregroundColour set];
	NSRectFill(rect);
	
	[pixmap unlockFocus];
	[zView setNeedsDisplay: YES];
}

- (void) plotText: (in bycopy NSString*) text
		  atPoint: (in NSPoint) point
		withStyle: (in bycopy ZStyle*) style {
	[pixmap lockFocusFlipped:YES];
		
	NSMutableDictionary* attr = [[zView attributesForStyle: style] mutableCopy];
	
	// Draw the background
	CGFloat height = [self sizeOfFont: [attr objectForKey: NSFontAttributeName]].height;
	CGFloat descender = [[attr objectForKey: NSFontAttributeName] descender];
	NSSize size = [text sizeWithAttributes: attr];
	
	point.y -= ceil(height)+1.0;
	
	size.height = height;
	NSRect backgroundRect;
	backgroundRect.origin = point;
	backgroundRect.size = size;
	backgroundRect.origin.y -= descender;
	
	backgroundRect.origin.x = floor(backgroundRect.origin.x);
	backgroundRect.origin.y = floor(backgroundRect.origin.y);
	backgroundRect.size.width = ceil(backgroundRect.size.width);
	backgroundRect.size.height = ceil(backgroundRect.size.height) + 1.0;
	
	[(NSColor*)[attr objectForKey: NSBackgroundColorAttributeName] set];
	NSRectFill(backgroundRect);
	
	// Draw the text
	[attr removeObjectForKey: NSBackgroundColorAttributeName];
	[text drawAtPoint: point
	   withAttributes: attr];
	
	[pixmap unlockFocus];
	[zView setNeedsDisplay: YES];
}

- (void) scrollRegion: (in NSRect) region
			  toPoint: (in NSPoint) where {
	[pixmap lockFocusFlipped:YES];
	
	// Used to use NSCopyBits but Apple randomly broke it sometime in Snow Leopard. The docs lied anyway.
	// This is much slower :-(
	NSBitmapImageRep*	copiedBits	= [[NSBitmapImageRep alloc] initWithFocusedViewRect: region];
	NSImage*			copiedImage	= [[NSImage alloc] init];
	[copiedImage addRepresentation: copiedBits];
	[copiedImage drawInRect: NSMakeRect(where.x, where.y, region.size.width, region.size.height)
				   fromRect: NSMakeRect(0,0, region.size.width, region.size.height)
				  operation: NSCompositeSourceOver
				   fraction: 1.0];
	
	
	// Uh, docs say we should use NSNullObject here, but it's not defined. Making a guess at its value (sigh)
	// This would be less of a problem in a view, because we can get the view's own graphics state. But you
	// can't get the graphics state for an image (in general).
	// NSCopyBits(0, region, where);
	[pixmap unlockFocus];
}

// = Measuring =

- (void) getInfoForStyle: (in bycopy ZStyle*) style
				   width: (out CGFloat*) width
				  height: (out CGFloat*) height
				  ascent: (out CGFloat*) ascent
				 descent: (out CGFloat*) descent {
    int fontnum;
	
    fontnum =
        (style.bold?1:0)|
        (style.underline?2:0)|
        (style.fixed?4:0)|
        (style.symbolic?8:0);

	NSFont* font = [zView fontWithStyle: fontnum];
    NSSize fontSize = [self sizeOfFont: font];
	
	*width = fontSize.width;
	*ascent = [font ascender];
	*descent = [font descender];
	*height = fontSize.height+1;
}

- (bycopy NSDictionary*) attributesForStyle: (in bycopy ZStyle*) style {
	return [zView attributesForStyle: style];
}

- (NSSize) measureString: (in bycopy NSString*) string
			   withStyle: (in bycopy ZStyle*) style {
	NSDictionary* attr = [zView attributesForStyle: style];
	
	return [string sizeWithAttributes: attr];
}

- (bycopy NSColor*) colourAtPixel: (NSPoint) point {
	[pixmap lockFocusFlipped:YES];
	
	if (point.x <= 0) point.x = 1;
	if (point.y <= 0) point.y = 1;
	
	NSColor* res = NSReadPixel(point);
	
	[pixmap unlockFocus];
	
	return [res copy];
}

// = Input =

- (void) setInputPosition: (NSPoint) point
				withStyle: (in bycopy ZStyle*) style {
	inputPos = point;
	if (inputStyle) {
		inputStyle = style;
	}
}

@synthesize inputPos;

- (ZStyle*) inputStyle {
	return inputStyle;
}

- (void) plotImageWithNumber: (in int) number
					 atPoint: (in NSPoint) point {
	NSImage* img = [[zView resources] imageWithNumber: number];

	NSRect imgRect;
	imgRect.origin = NSMakePoint(0,0);
	imgRect.size = [img size];
	
	NSRect destRect;
	destRect.origin = point;
	destRect.size = [[zView resources] sizeForImageWithNumber: number
												forPixmapSize: [pixmap size]];
	
	[pixmap lockFocusFlipped:YES];
	[img drawInRect: destRect
		   fromRect: imgRect
		  operation: NSCompositeSourceOver
		   fraction: 1.0];
	[pixmap unlockFocus];
	
	[zView setNeedsDisplay: YES];
}

// = NSCoding =
- (void) encodeWithCoder: (NSCoder*) encoder {
	[encoder encodeObject: pixmap];
	
	[encoder encodePoint: inputPos];
	[encoder encodeObject: inputStyle];
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
    if (self) {
		pixmap = [decoder decodeObject];
		inputPos = [decoder decodePoint];
		inputStyle = [decoder decodeObject];
    }
	
    return self;
}

@synthesize zoomView=zView;

// = Input styles =

- (oneway void) setInputStyle: (in bycopy ZStyle*) newInputStyle {
	// Do nothing
}

@end
