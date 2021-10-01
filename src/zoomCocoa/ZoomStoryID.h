//
//  ZoomStoryID.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface ZoomStoryID : NSObject<NSCopying, NSSecureCoding> {
	struct IFID* ident;
	BOOL needsFreeing;
}

+ (ZoomStoryID*) idForFile: (NSString*) filename;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (id) initWithZCodeStory: (NSData*) gameData NS_DESIGNATED_INITIALIZER;
- (id) initWithZCodeFile: (NSString*) zcodeFile NS_DESIGNATED_INITIALIZER;
- (id) initWithGlulxFile: (NSString*) glulxFile NS_DESIGNATED_INITIALIZER;
- (id) initWithData: (NSData*) genericGameData;
- (id) initWithData: (NSData*) genericGameData
			   type: (NSString*) type NS_DESIGNATED_INITIALIZER;
- (id) initWithIdent: (struct IFID*) ident NS_DESIGNATED_INITIALIZER;
- (id) initWithIdString: (NSString*) idString NS_DESIGNATED_INITIALIZER;
- (id) initWithZcodeRelease: (int) release
					 serial: (const unsigned char*) serial
				   checksum: (int) checksum NS_DESIGNATED_INITIALIZER;

@property (readonly) struct IFID *ident NS_RETURNS_INNER_POINTER;

- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

@end

//! Set to \c YES to prevent the plug-in manager from looking at plug-ins.
extern BOOL ZoomIsSpotlightIndexing;
