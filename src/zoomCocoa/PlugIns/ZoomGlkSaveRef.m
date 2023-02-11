//
//  ZoomGlkSaveRef.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 15/07/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import "ZoomGlkSaveRef.h"
#import "ZoomSkein.h"
#import <GlkView/GlkFileRef.h>
#import <GlkView/GlkFileStream.h>
#import <ZoomView/ZoomView-Swift.h>

@implementation ZoomGlkSaveRef {
	//! The plugin specifying what is creating this fileref
	ZoomPlugIn* plugin;
	//! The file URL for this fileref
	NSURL* path;
	
	//! The preview lines to save for this object
	NSArray<NSString*>* preview;
	//! The skein to save for this object (or the skein loaded for this object)
	ZoomSkein* skein;
	
	//! The delegate for this object
	id<ZoomGlkSaveRefDelegate> delegate;
	//! The autoflush flag
	BOOL autoflush;
}

#pragma mark - Initialisation

- (id) initWithPlugIn: (ZoomPlugIn*) newPlugin
			  saveURL: (NSURL *) newPath {
	self = [super init];
	
	if (self) {
		// Return nil if the path doesn't end in .glksave (or it does and isn't a directory)
		BOOL isDir;
		if (![[NSFileManager defaultManager] fileExistsAtPath: newPath.path
												  isDirectory: &isDir]) {
			isDir = YES;
		}
			
		if (![[[newPath pathExtension] lowercaseString] isEqualToString: @"glksave"] || !isDir) {
			return nil;
		}
		
		// Set up the plugin and path for this object
		plugin = newPlugin;
		path = [newPath copy];
	}
	
	return self;
}

+ (id<GlkFileRef>) createRefWithPlugIn: (ZoomPlugIn *) plugIn
							   saveURL: (NSURL *) newPath {
	// Revert to being a standard GlkFileRef if the path doesn't end in .glksave (or it does and isn't a directory)
	BOOL isDir;
	if (![[NSFileManager defaultManager] fileExistsAtPath: newPath.path
											  isDirectory: &isDir]) {
		isDir = YES;
	}

	if (![[[newPath pathExtension] lowercaseString] isEqualToString: @"glksave"] || !isDir) {
		return [[GlkFileRef alloc] initWithPath: newPath];
	}

	return [[ZoomGlkSaveRef alloc] initWithPlugIn: plugIn saveURL: newPath];
}

#pragma mark - Creating the glksave package

- (BOOL) createSavePackage {
	// Constructs a save package at the specified path
	NSError* error;
	
	// Build the property list wrapper
	NSDictionary* saveProperties = [NSDictionary dictionaryWithObjectsAndKeys:
		[plugin gameURL].path, @"ZoomGlkGameFileName",
		[[plugin idForStory] description], @"ZoomGlkGameId",
		[[plugin class] pluginDescription], @"ZoomGlkPluginDescription",
		[[plugin class] pluginAuthor], @"ZoomGlkPluginAuthor",
		[[plugin class] pluginVersion], @"ZoomGlkPluginVersion",
		nil];
	NSData* savePropertyList = [NSPropertyListSerialization dataWithPropertyList: saveProperties
																		  format: NSPropertyListXMLFormat_v1_0
																		 options: 0
																		   error: &error];
	if (error) {
		error = nil;
	}
	
	NSFileWrapper* savePropertyWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: savePropertyList];
	[savePropertyWrapper setPreferredFilename: @"Info.plist"];
	
	// Build the save game file itself
	NSData* emptySaveGame = [NSData data];
	
	NSFileWrapper* saveGameWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: emptySaveGame];
	[saveGameWrapper setPreferredFilename: @"Save.data"];
	
	// Build the skein data
	NSFileWrapper* skeinWrapper = nil;
	
	if (skein) {
		NSData* skeinData = [[skein xmlData] dataUsingEncoding: NSUTF8StringEncoding];
		if (skeinData) {
			skeinWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: skeinData];
			[skeinWrapper setPreferredFilename: @"Skein.skein"];
		}
	}
	
	// Build the preview data
	NSFileWrapper* previewWrapper = nil;
	
	if (preview) {
		NSData* previewData = [NSPropertyListSerialization dataWithPropertyList: preview
																		 format: NSPropertyListXMLFormat_v1_0
																		options: 0
															   error: &error];
		if (error) {
			error = nil;
		}
		
		if (previewData) {
			previewWrapper = [[NSFileWrapper alloc] initRegularFileWithContents: previewData];
			[previewWrapper setPreferredFilename: @"Preview.plist"];
		}
	}
	
	// Build the final save wrapper
	NSFileWrapper* saveWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:@{
		@"Info.plist": savePropertyWrapper,
		@"Save.data": saveGameWrapper}];
	
	if (skeinWrapper) {
		[saveWrapper addFileWrapper: skeinWrapper];
	}
	if (previewWrapper) {
		[saveWrapper addFileWrapper: previewWrapper];
	}
	
	// Write it out
	if (![saveWrapper writeToURL: path
						 options: (NSFileWrapperWritingAtomic | NSFileWrapperWritingWithNameUpdating)
			 originalContentsURL: nil
						   error: NULL]) {
		return NO;
	}
	
	// Set the icon
	NSImage* iconImage = [plugin coverImage];
	if (iconImage) {
		NSImage* originalImage = [[NSWorkspace sharedWorkspace] iconForFileType: @"glksave"];
		NSImage* newImage = [[NSImage alloc] initWithSize: NSMakeSize(128, 128)];
		
		// Pick the 128x128 representation of the original
		NSEnumerator<NSImageRep*>* originalImageRepEnum = [[originalImage representations] objectEnumerator];
		NSImageRep* rep;
		for (rep in originalImageRepEnum) {
			if ([rep size].width >= 128.0) break;
		}
		
		if (rep != nil) {
			originalImage = [[NSImage alloc] init];
			[originalImage addRepresentation: rep];
		}
		
		NSSize iconSize = [iconImage size];
		
		// Set the background for the image
		[newImage lockFocus];
		[[NSColor clearColor] set];
		NSRectFill(NSMakeRect(0,0,128,128));
		
		CGFloat scaleFactor;
		
		if (originalImage == nil || iconSize.width > 256 || iconSize.height > 256) {
			// Just use the cover image as the image for this save game
			scaleFactor = 128.0;
		} else {
			// Use a combined icon for this save game
			scaleFactor = 64.0;
			[originalImage drawInRect: NSMakeRect(0,0,128,128)
							 fromRect: NSZeroRect
							operation: NSCompositingOperationSourceOver
							 fraction: 1.0];
		}
		
		// Draw the icon on top
		if (iconSize.width > iconSize.height) {
			scaleFactor /= iconSize.width;
		} else {
			scaleFactor /= iconSize.height;
		}
		
		NSSize newSize = NSMakeSize(iconSize.width * scaleFactor, iconSize.height * scaleFactor);
		
		[iconImage drawInRect: NSMakeRect(64-newSize.width/2, 64-newSize.height/2, newSize.width, newSize.height)
					 fromRect: NSZeroRect
					operation: NSCompositingOperationSourceOver
					 fraction: 1.0];
		
		// Finish up
		[newImage unlockFocus];
		
		// Set the image for this save game
//		[path setResourceValue:newImage forKey:NSURLCustomIconKey error:NULL];
		[[NSWorkspace sharedWorkspace] setIcon: newImage
									   forFile: path.path
									   options: NSExcludeQuickDrawElementsIconCreationOption];
	}

	// Report success
	return YES;
}

#pragma mark - Properties

@synthesize delegate;

- (void) setPreview: (NSArray*) newPreview {
	preview = [[NSArray alloc] initWithArray: newPreview
								   copyItems: YES];
}

@synthesize skein;
	
#pragma mark - GlkFileRef implementation

- (byref id<GlkStream>) createReadOnlyStream {
	// Load the skein from the path if it exists
	NSURL* skeinPath = [path URLByAppendingPathComponent: @"Skein.skein"];
	if ([skeinPath checkResourceIsReachableAndReturnError: NULL]) {
		if (!skein) skein = [[ZoomSkein alloc] init];
		
		[skein parseXMLContentsAtURL: skeinPath error: NULL];
	}
	
	// Inform the delegate we're about to start reading
	if ([delegate respondsToSelector: @selector(readingFromSaveFile:)]) {
		[delegate readingFromSaveFile: self];
	}
	
	// Create a read-only stream
	GlkFileStream* stream = [[GlkFileStream alloc] initForReadingFromFileURL: [path URLByAppendingPathComponent: @"Save.data"]];
	
	return stream;
}

- (byref id<GlkStream>) createWriteOnlyStream {
	if ([self createSavePackage]) {
		GlkFileStream* stream = [[GlkFileStream alloc] initForWritingToFileURL: [path URLByAppendingPathComponent: @"Save.data"]];
		
		return stream;
	}
	
	// Couldn't (re)create the file
	return nil;
}

- (byref id<GlkStream>) createReadWriteStream {
	NSLog(@"WARNING: Save game files should not be opened read/write");
	
	// Try creating the savegame file
	if (![self createSavePackage]) {
		return nil;
	}
	
	// Construct a read/write stream
	GlkFileStream* stream = [[GlkFileStream alloc] initForReadWriteWithFileURL: [path URLByAppendingPathComponent: @"Save.data"]];
	
	return stream;			
}

- (void) deleteFile {
	[[NSFileManager defaultManager] removeItemAtURL: path
											  error: NULL];
}

- (BOOL) fileExists {
	return [[NSFileManager defaultManager] fileExistsAtPath: path.path];
}

@synthesize autoflushStream = autoflush;

- (bycopy NSURL *)fileURL
{
	return [path URLByAppendingPathComponent: @"Save.data"];
}

@end
