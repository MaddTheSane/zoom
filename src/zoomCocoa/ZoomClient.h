//
//  ZoomClient.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomProtocol.h"
#import "ZoomStory.h"
#import "ZoomSkein.h"
#import "ZoomBlorbFile.h"

@class ZoomView;
@interface ZoomClient : NSDocument {
    NSData* gameData;
	
	ZoomStory* story;
	ZoomStoryID* storyId;
	
	NSData* autosaveData;
	
	ZoomView*  defaultView;
	ZoomSkein* skein;
	NSData*   saveData;
	
	ZoomBlorbFile* resources;
	
	BOOL wasRestored;
	
	NSMutableArray* loadingErrors;
}

@property (readonly, retain) NSData *gameData;
@property (readonly, retain) ZoomStory *storyInfo;
@property (readonly, retain) ZoomStoryID *storyId;
@property (readonly, retain) ZoomSkein *skein;

// Restoring from an autosave
- (void) loadDefaultAutosave;
@property (retain) NSData *autosaveData;

// Loading a zoomSave file
@property (readonly, retain) ZoomView *defaultView;
@property (copy) NSData *saveData;

// Resources
@property (retain) ZoomBlorbFile *resources;

// Errors that might have happened but we recovered from (for example, resources not found)
- (void) addLoadingError: (NSString*) loadingError;
- (NSArray<NSString*>*) loadingErrors;

@end
