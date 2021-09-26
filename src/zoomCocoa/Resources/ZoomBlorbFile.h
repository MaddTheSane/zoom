//
//  ZoomBlorbFile.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jul 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ZoomView/ZoomProtocol.h>

@interface ZoomBlorbFile : NSObject {
	NSObject<ZFile>* file;
	
	NSString*       formID;
	unsigned int    formLength;

	NSMutableArray<NSDictionary<NSString*,id>*>*		 iffBlocks;
	NSMutableDictionary<NSString*,NSMutableArray<NSDictionary<NSString*,id>*>*>* typesToBlocks;
	NSMutableDictionary<NSNumber*,NSDictionary<NSString*,id>*>* locationsToBlocks;
	
	NSMutableDictionary<NSString*,NSMutableDictionary<NSNumber*,NSNumber*>*>* resourceIndex;
	
	BOOL adaptive;
	NSMutableSet<NSNumber*>* adaptiveImages;
	NSData*       activePalette;
	
	NSSize stdSize;
	NSSize minSize;
	NSSize maxSize;
	NSMutableDictionary* resolution;
	
	NSMutableDictionary<NSNumber*, NSMutableDictionary*>* cache;
	unsigned int maxCacheNum;
}

// Testing files
+ (BOOL) dataIsBlorbFile: (NSData*) data;
+ (BOOL) fileContentsIsBlorb: (NSString*) filename;
+ (BOOL) zfileIsBlorb: (NSObject<ZFile>*) file;

// Initialisation
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (id) initWithZFile: (NSObject<ZFile>*) file NS_DESIGNATED_INITIALIZER; //!< Designated initialiser
- (id) initWithData: (NSData*) blorbFile;
- (id) initWithContentsOfFile: (NSString*) filename;

// Cache control
- (void) removeAdaptiveImagesFromCache;

// Generic IFF data
- (NSArray*) chunksWithType: (NSString*) chunkType;
- (NSData*) dataForChunk: (id) chunk;
- (NSData*) dataForChunkWithType: (NSString*) chunkType;

// The resource index
- (BOOL) parseResourceIndex;
- (BOOL) containsImageWithNumber: (int) num;

// Typed data
- (NSData*) imageDataWithNumber: (int) num;
- (NSData*) soundDataWithNumber: (int) num;

// Decoded data
- (NSImage*) imageWithNumber: (int) num;
- (NSSize) sizeForImageWithNumber: (int) num
					forPixmapSize: (NSSize) pixmapSize;
@end
