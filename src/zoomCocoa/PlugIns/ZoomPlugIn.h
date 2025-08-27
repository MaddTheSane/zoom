//
//  ZoomPlugIn.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 24/11/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//


#ifndef __ZOOMPLUGINS_ZOOMPLUGIN_H__
#define __ZOOMPLUGINS_ZOOMPLUGIN_H__

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomStory.h>
#import <ZoomPlugIns/ZoomStoryID.h>

NS_ASSUME_NONNULL_BEGIN

@class UTType;

///
/// Base class for deriving Zoom plugins for playing new game types.
///
/// Note that plugins can be initialised in two circumstances: when retrieving game metadata, or when actually playing
/// the game. Game metadata might be requested from a seperate thread, notably when Zoom refreshes the
/// iFiction window on startup.
///
@interface ZoomPlugIn : NSObject

// Informational functions (subclasses should normally override)
//! The version of this plugin
@property (class, readonly, copy) NSString *pluginVersion;
//! The description of this plugin
@property (class, readonly, copy) NSString *pluginDescription;
//! The author of this plugin
@property (class, readonly, copy) NSString *pluginAuthor;

/// `YES` if this plugin can load savegames as well as game files.
@property (class, readonly) BOOL canLoadSavegames;

/// `YES` if the plug-in requires the path of the file to be passed as an argument.
///
/// This might be needed if, for example, the client hasn't been ported to use CocoaGlk, or
/// it is non-trivial to do so. Default is `NO`.
@property (class, readonly) BOOL needsPathPassedToTask;

/// `YES` if the specified file URL is one that the plugin can run.
///
/// A non-existant file might be sent: If the file doesn't exist, check the file extension only.
+ (BOOL) canRunURL: (NSURL*) path;

/// Return an array of file types that an `NSOpenPanel` can select from.
///
/// This may be UTIs, file extensions, or OSTypes (Created by `NSFileTypeForHFSTypeCode()` or similar).
@property (class, readonly, copy) NSArray<NSString*> *supportedFileTypes;

/// Return an array of content types that an `NSOpenPanel` can select from.
///
/// If your plug-in doesn't implement this method, the default implemention takes the
/// class property ``+supportedFileTypes`` and creates `UTType`s from the
/// parsed extensions, UTIs, and OSTypes.
///
/// - warning: Unless the type identifiers are present in Zoom's **Info.plist** or declared by another application,
/// `+[UTType typeWithIdentifier:]` *will* fail and `+[UTType importedTypeWithIdentifier:]`
/// will complain. The best way to handle this is to *not* implement this class property and instead
/// let the default implementation create them from your own ``+supportedFileTypes``.
@property (class, readonly, copy) NSArray<UTType*> *supportedContentTypes;

// Designated initialiser
//! Initialises this plugin to play a specific game
- (nullable id) initWithURL: (NSURL*) gameFile NS_DESIGNATED_INITIALIZER;

// Getting information about what this plugin should be doing
//! Gets the game associated with this plugin
@property (readonly, copy) NSURL *gameURL;
//! Gets the data for the game associated with this plugin
@property (readonly, copy, nullable) NSData *gameData;

// The game document + windows
//! Retrieves/creates the document associated with this game (should not create window controllers immediately)
- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story;

//! Retrieves/creates the document associated with this game along with the specified save game file (should not create window controllers immediately)
- (NSDocument*) gameDocumentWithMetadata: (ZoomStory*) story
							 saveGameURL: (NSURL*) saveGame;

// Dealing with game metadata
//! Retrieves the unique ID for this story (UUIDs are preferred, or MD5s if the game format does not support that)
- (nullable ZoomStoryID*) idForStory;
//! Retrieves the default metadata for this story (used iff no metadata pre-exists for this story)
- (nullable ZoomStory*) defaultMetadataWithError:(NSError**)outError;
//! Retrieves the picture to use for the cover image
@property (readonly, nonatomic, copy, nullable) NSImage *coverImage;

//! Resizes a cover image so that it's suitable for use as a window logo
- (NSImage*) resizeLogo: (NSImage*) input;

// More information from the main Zoom application
//! Sets the preferred directory to put savegames into
- (void) setPreferredSaveDirectoryURL: (null_unspecified NSURL*) dir;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END

#endif
