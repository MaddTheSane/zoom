//
//  ZoomSavePreview.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Mar 27 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import <ZoomView/ZoomUpperWindow.h>

@interface ZoomSavePreview : NSView {
	NSString* filename;
	ZoomUpperWindow* preview;
	NSArray* previewLines;
	
	BOOL highlighted;
}

- (instancetype)initWithFrame:(NSRect)frame NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)decoder NS_DESIGNATED_INITIALIZER;
- (id) initWithPreview: (ZoomUpperWindow*) prev
			  filename: (NSString*) filename;
- (id) initWithPreviewStrings: (NSArray<NSString*>*) prev
					 filename: (NSString*) filename;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (readonly, copy) NSString *filename;

- (IBAction) deleteSavegame: (id) sender;

@end
