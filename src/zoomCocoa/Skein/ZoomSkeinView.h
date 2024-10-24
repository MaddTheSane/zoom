//
//  ZoomSkeinView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sat Jul 03 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

#import <ZoomView/ZoomSkein.h>
#import <ZoomView/ZoomSkeinItem.h>
#import <ZoomView/ZoomSkeinLayout.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ZoomSkeinViewDelegate;

extern NSPasteboardType const ZoomSkeinItemPboardType NS_SWIFT_NAME(zoomSkeinItem);
extern NSString * const ZoomSkeinTranscriptURLDefaultsKey;

@interface ZoomSkeinView : NSView <NSTextViewDelegate, NSDraggingDestination, NSDraggingSource, NSControlTextEditingDelegate> {
	BOOL skeinNeedsLayout;
}

/// Setting/getting the source
@property (nonatomic, strong) ZoomSkein* skein;

#pragma mark Laying things out
- (void) skeinNeedsLayout;

@property (nonatomic) CGFloat itemWidth;
@property (nonatomic) CGFloat itemHeight;

/// The delegate
@property (weak) id<ZoomSkeinViewDelegate> delegate;

#pragma mark Affecting the display
- (void) scrollToItem: (nullable ZoomSkeinItem*) item;

- (void) editItem: (ZoomSkeinItem*) skeinItem;
- (void) editItemAnnotation: (ZoomSkeinItem*) skeinItem;
@property (nullable, strong) ZoomSkeinItem *selectedItem;

- (void) highlightSkeinLine: (ZoomSkeinItem*) itemOnLine;

- (void) layoutSkein;

- (IBAction)updateSkein:(nullable id)sender;

@end


#pragma mark - Delegate

@protocol ZoomSkeinViewDelegate <NSObject>
@optional

#pragma mark Playing the game
- (void) restartGame;
- (void) playToPoint: (ZoomSkeinItem*) point
		   fromPoint: (ZoomSkeinItem*) currentPoint;

#pragma mark The transcript
- (void) transcriptToPoint: (ZoomSkeinItem*) point;

#pragma mark Various types of possible error
/// User attempted to delete an item on the active skein branch (which can't be done)
- (void) cantDeleteActiveBranch;
/// User attemptted to edit the root skein item
- (void) cantEditRootItem;

@end

NS_ASSUME_NONNULL_END
