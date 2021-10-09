//
//  ZoomMetadata.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ZoomPlugIns/ZoomStory.h>
#import <ZoomPlugIns/ZoomStoryID.h>

// Notifications
//! A story with a particular ID will be destroyed
extern NSNotificationName const ZoomMetadataWillDestroyStory;

extern NSErrorDomain const ZoomMetadataErrorDomain;
typedef NS_ERROR_ENUM(ZoomMetadataErrorDomain, ZoomMetadataError) {
	ZoomMetadataErrorProgrammerIsASpoon,
	ZoomMetadataErrorXML,
	ZoomMetadataErrorNotXML,
	ZoomMetadataErrorUnknownVersion,
	ZoomMetadataErrorUnknownTag,
	ZoomMetadataErrorNotIFIndex,
	ZoomMetadataErrorUnknownFormat,
	ZoomMetadataErrorMismatchedFormats,
	
	ZoomMetadataErrorStoriesShareIDs,
	ZoomMetadataErrorDuplicateID
};

//! Cocoa interface to the C ifmetadata class
@interface ZoomMetadata : NSObject {
	NSString* filename;
	IFMetabase metadata;
	
	NSLock* dataLock;
}

// Initialisation
//! Blank metadata
- (id) init;
//! Calls initWithData
- (id) initWithContentsOfFile: (NSString*) filename;
//! Designated initialiser
- (id) initWithData: (NSData*) xmlData;

// Thread safety [called by ZoomStory]
- (void) lock;
- (void) unlock;
	
// Information about the parse
- (NSArray*) errors;

// Retrieving information
- (BOOL) containsStoryWithIdent: (ZoomStoryID*) ident;
- (ZoomStory*) findOrCreateStory: (ZoomStoryID*) ident;
@property (readonly, nonatomic, copy) NSArray<ZoomStory*> *stories;

// Storing information
- (void) copyStory: (ZoomStory*) story;
- (void) copyStory: (ZoomStory*) story
			  toId: (ZoomStoryID*) copyID;
- (void) removeStoryWithIdent: (ZoomStoryID*) ident;

// Saving the file
- (NSData*) xmlData;
- (BOOL)    writeToFile: (NSString*)path
			 atomically: (BOOL)flag;
- (BOOL)    writeToURL: (NSURL*)path
			atomically: (BOOL)flag
				 error: (NSError**)error;
- (BOOL) writeToDefaultFile;

@end
