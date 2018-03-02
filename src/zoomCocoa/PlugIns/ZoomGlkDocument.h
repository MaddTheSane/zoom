//
//  ZoomGlkDocument.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 18/01/2006.
//  Copyright 2006 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomPlugIns/ZoomStory.h>

@class ZoomPlugIn;

NS_ASSUME_NONNULL_BEGIN

///
/// Document representing a Glk game
///
@interface ZoomGlkDocument : NSDocument {
	NSString* clientPath;											// The Glk executable we'll run to play this game
	NSString* inputPath;											// The file we'll pass to the executable as the game to run
	NSString* savedGamePath;										// The file that we'll pass as a savegame
	
	ZoomStory* storyData;											// Metadata for this story
	ZoomPlugIn* plugIn;
	NSImage* logo;													// The logo for this story
	NSString* preferredSaveDir;										// Preferred save directory
}

// Configuring the client
//! The metadata associated with this story
@property (retain) ZoomStory *storyData;
//! Selects which GlkClient executable to run
@property (copy) NSString *clientPath;
- (void) setInputFilename: (NSString*) inputPath;					// The file that should be passed to the client as the file to run
//! The logo to display for this story
@property (retain) NSImage *logo;
//! The plugin that created this document
@property (retain) ZoomPlugIn *plugIn;
//! A .glksave file that the game should load on first start up
@property (copy, nullable) NSString *saveGame;

//! The preferred directory to put savegames into
@property (copy) NSString *preferredSaveDirectory;

@end

NS_ASSUME_NONNULL_END

#import <ZoomPlugIns/ZoomPlugIn.h>
