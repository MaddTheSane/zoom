//
//  ZoomStory.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZoomMetadata;

// Notifications
extern NSNotificationName const ZoomStoryDataHasChangedNotification;

typedef NS_ENUM(unsigned, IFMB_Zarfian) {
	IFMD_Unrated = 0x0,
	IFMD_Merciful,
	IFMD_Polite,
	IFMD_Tough,
	IFMD_Nasty,
	IFMD_Cruel
};

@class ZoomStoryID;
@interface ZoomStory : NSObject {
	struct IFStory* story;
	BOOL   needsFreeing;
	
	ZoomMetadata* metadata;
	
	NSMutableDictionary* extraMetadata;
}

// Information
+ (NSString*) nameForKey: (NSString*) key;
+ (NSString*) keyForTag: (NSInteger) tag;

// Initialisation
+ (ZoomStory*) defaultMetadataForFile: (NSString*) filename;

- (id) initWithStory: (struct IFStory*) story
			metadata: (ZoomMetadata*) metadataContainer;

@property (readonly) struct IFStory *story NS_RETURNS_INNER_POINTER;
- (void) addID: (ZoomStoryID*) newID;

// Searching
- (BOOL) containsText: (NSString*) text;

// Accessors
@property (copy)	NSString *title;
@property (copy)	NSString *headline;
@property (copy)	NSString *author;
@property (copy)	NSString *genre;
@property int		year;
@property (copy)	NSString *group;
@property IFMB_Zarfian zarfian;
@property (copy)	NSString *teaser;
@property (copy)	NSString *comment;
@property float		rating;

- (int)		  coverPicture;
- (NSString*) description;

- (id) objectForKey: (NSString*) key; //!< Always returns an NSString (other objects are possible for other metadata)

// Setting data
- (void) setTitle:		  (NSString*) newTitle;
- (void) setHeadline:	  (NSString*) newHeadline;
- (void) setAuthor:		  (NSString*) newAuthor;
- (void) setGenre:		  (NSString*) genre;
- (void) setYear:		  (int) year;
- (void) setGroup:		  (NSString*) group;
- (void) setZarfian:	  (IFMB_Zarfian) zarfian;
- (void) setTeaser:		  (NSString*) teaser;
- (void) setComment:	  (NSString*) comment;
- (void) setRating:		  (float) rating;

- (void) setCoverPicture: (int) picture;
- (void) setDescription:  (NSString*) description;

- (void) setObject: (id) value
			forKey: (NSString*) key;

// Identifying and comparing stories
//! Compound ID
- (ZoomStoryID*) storyID;
//! Array of ZoomStoryIDs
@property (nonatomic, readonly, copy) NSArray<ZoomStoryID*> *storyIDs;
//! Story answers to this ID
- (BOOL)     hasID: (ZoomStoryID*) storyID;
//! Stories share an ID
- (BOOL)     isEquivalentToStory: (ZoomStory*) story;

// Sending notifications
//! Sends \c ZoomStoryDataHasChangedNotification
- (void) heyLookThingsHaveChangedOohShiney;

//! New story (DEPRECATED)
- (id) init DEPRECATED_ATTRIBUTE;

@end

#import <ZoomPlugIns/ZoomMetadata.h>
