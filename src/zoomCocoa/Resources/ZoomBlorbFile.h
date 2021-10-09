//
//  ZoomBlorbFile.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Fri Jul 30 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <ZoomView/ZoomProtocol.h>

@interface ZoomBlorbFile : NSObject

// Testing files
+ (BOOL) dataIsBlorbFile: (NSData*) data;
+ (BOOL) fileContentsIsBlorb: (NSString*) filename;
+ (BOOL) zfileIsBlorb: (id<ZFile>) file;

// Initialisation
- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (id) initWithZFile: (id<ZFile>) file NS_DESIGNATED_INITIALIZER; //!< Designated initialiser
- (id) initWithData: (NSData*) blorbFile;
- (id) initWithContentsOfFile: (NSString*) filename;
- (instancetype) initWithContentsOfURL: (NSURL*) filename error: (NSError**) outError;

// Cache control
- (void) removeAdaptiveImagesFromCache;

// Generic IFF data
- (NSArray<NSDictionary<NSString*,id>*>*) chunksWithType: (NSString*) chunkType;
- (NSData*) dataForChunk: (NSDictionary<NSString*,id>*) chunk;
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
