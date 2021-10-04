//
//  ZoomStoryID.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ZoomStoryID : NSObject<NSCopying, NSSecureCoding> {
	struct IFID* ident;
	BOOL needsFreeing;
}

+ (nullable ZoomStoryID*) idForFile: (NSString*) filename;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (nullable instancetype) initWithZCodeStory: (NSData*) gameData;
- (nullable instancetype) initWithZCodeFile: (NSString*) zcodeFile;
- (nullable instancetype) initWithGlulxFile: (NSString*) glulxFile;
- (nullable instancetype) initWithData: (NSData*) genericGameData;
- (nullable instancetype) initWithData: (NSData*) genericGameData
								  type: (NSString*) type;
- (instancetype) initWithIdent: (struct IFID*) ident;
- (instancetype) initWithIdString: (NSString*) idString;
- (instancetype) initWithZcodeRelease: (int) release
							   serial: (const unsigned char*) serial
							 checksum: (int) checksum;

@property (readonly) struct IFID *ident NS_RETURNS_INNER_POINTER;

- (nullable instancetype)initWithCoder:(NSCoder *)coder;

@end

//! Set to \c YES to prevent the plug-in manager from looking at plug-ins.
extern BOOL ZoomIsSpotlightIndexing;

NS_ASSUME_NONNULL_END
