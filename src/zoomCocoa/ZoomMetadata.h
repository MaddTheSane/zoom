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

NS_ASSUME_NONNULL_BEGIN

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
@interface ZoomMetadata : NSObject

// Initialisation
//! Blank metadata
- (id) init NS_DESIGNATED_INITIALIZER;

//! Designated initialiser.
//!
//! Call one of the convenience initializers instead!
//! \param xmlData The raw XML data.
//! \param fname File URL of the data in \c xmlData .
//! \param error Error value, populated on failure (returned nil).
- (nullable instancetype) initWithData: (NSData*) xmlData
							   fileURL: (nullable NSURL*) fname
								 error: (NSError**) error NS_DESIGNATED_INITIALIZER;


//! Gets data from filename, then calls initWithData:fileURL:error:
- (nullable instancetype) initWithContentsOfURL: (NSURL*) filename error: (NSError**) outError;

@property (readonly, copy, nullable) NSURL *sourceURL;

//! Calls initWithData:fileURL:error:
- (nullable instancetype) initWithData: (NSData*) xmlData error: (NSError**) outError;

// Thread safety [called by ZoomStory]
- (void) lock;
- (void) unlock;
	
// Information about the parse
@property (readonly, copy) NSArray<NSString*> *errors;

// Retrieving information
- (BOOL) containsStoryWithIdent: (ZoomStoryID*) ident;
- (null_unspecified ZoomStory*) findOrCreateStory: (ZoomStoryID*) ident;
- (nullable ZoomStory*) findStory: (ZoomStoryID*) ident;
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
				 error: (NSError*__autoreleasing*)error;
- (BOOL) writeToSourceURLAtomically: (BOOL)flag
							  error: (NSError*__autoreleasing*)error;
- (BOOL) writeToDefaultFileWithError: (NSError*__autoreleasing*) outError;

@end

NS_ASSUME_NONNULL_END
