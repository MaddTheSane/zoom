//
//  ZoomGlkSaveRef.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 15/07/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomPlugIn.h>
#import <GlkView/GlkFileRefProtocol.h>


NS_ASSUME_NONNULL_BEGIN

@protocol ZoomGlkSaveRefDelegate;
@class ZoomSkein;

///
/// GlkFileRef object that can be used to create a .glksave package
///
@interface ZoomGlkSaveRef : NSObject<GlkFileRef>

// Initialisation

/// Initialises a saveref that saves files from the specified plugin object to the specified file URL.
- (nullable id) initWithPlugIn: (ZoomPlugIn*) plugin
					   saveURL: (NSURL*) path;

/// Creates a saveref that saves files from the specified plugin object to the specified file URL.
+ (nullable id<GlkFileRef>) createRefWithPlugIn: (ZoomPlugIn*) plugIn
										saveURL: (NSURL*) path NS_RETURNS_RETAINED;

// Extra properties
//! Sets the delegate for this object (the delegate is retained)
@property (strong, nullable) id<ZoomGlkSaveRefDelegate> delegate;

//! An array of strings that can be used for the preview for this file
- (void) setPreview: (NSArray<NSString*>*) preview;
//! Sets the skein that will be saved with this reference
//! Retrieves a skein previously set with setSkein, or the skein most recently loaded for this file
@property (retain, nullable) ZoomSkein *skein;

@end

///
/// ZoomGlkSaveRef delegate methods
///
@protocol ZoomGlkSaveRefDelegate <NSObject>
@optional

//! Call back to indicate that we're reading from a specific save file
- (void) readingFromSaveFile: (ZoomGlkSaveRef*) file;

@end

NS_ASSUME_NONNULL_END
