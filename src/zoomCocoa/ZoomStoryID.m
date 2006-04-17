//
//  ZoomStoryID.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Jan 13 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import "ZoomStoryID.h"
#import "ZoomBlorbFile.h"

#include "ifmetabase.h"

@implementation ZoomStoryID

- (id) initWithZCodeStory: (NSData*) gameData {
	self = [super init];
	
	if (self) {
		const unsigned char* bytes = [gameData bytes];
		int length = [gameData length];
		
		if ([gameData length] < 64) {
			// Too little data for this to be a Z-Code file
			[self release];
			return nil;
		}

		if (bytes[0] == 'F' && bytes[1] == 'O' && bytes[2] == 'R' && bytes[3] == 'M') {
			// This is not a Z-Code file; it's possibly a blorb file, though
			
			// Try to interpret as a blorb file
			ZoomBlorbFile* blorbFile = [[ZoomBlorbFile alloc] initWithData: gameData];
			
			if (blorbFile == nil) {
				[self release];
				return nil;
			}
			
			// See if we can get the ZCOD chunk
			NSData* data = [blorbFile dataForChunkWithType: @"ZCOD"];
			if (data == nil) {
				[blorbFile release];
				[self release];
				return nil;
			}
			
			if ([data length] < 64) {
				// This file is too short to be a Z-Code file
				[blorbFile release];
				[self release];
				return nil;
			}
			
			// Change to using the blorb data instead
			bytes = [[[data retain] autorelease] bytes];
			length = [data length];
			[blorbFile release];
		}
		
		// Interpret the Z-Code data into a identification
		ident = IFID_Alloc();
		needsFreeing = YES;
		
		ident->format = ident->dataFormat = IFFormat_ZCode;

		memcpy(ident->data.zcode.serial, bytes + 0x12, 6);
		ident->data.zcode.release  = (((int)bytes[0x2])<<8)|((int)bytes[0x3]);
		ident->data.zcode.checksum = (((int)bytes[0x1c])<<8)|((int)bytes[0x1d]);
		ident->usesMd5 = 0;
		
		// Scan for the string 'UUID://' - use this as an ident for preference if it exists (and represents a valid UUID)
		struct IFMDUUID uuid;
		int x;
		BOOL gotUUID = NO;
		
		for (x=0; x<16; x++) uuid.uuid[x] = 0;
		
		for (x=0; x<length-48; x++) {
			if (bytes[x] == 'U' && bytes[x+1] == 'U' && bytes[x+2] == 'I' && bytes[x+3] == 'D' &&
				bytes[x+4] == ':' && bytes[x+5] == '/' && bytes[x+6] == '/') {
				// This might be a UUID section
				uuid = IFMD_ReadUUID((char*)(bytes + x + 7));
				
				// Check to see if we've got a UUID
				int y;
				gotUUID = NO;
				
				for (y=0; y<16; y++) {
					if (uuid.uuid[y] != 0) gotUUID = YES;
				}
				
				if (gotUUID) break;
			}
		}
		
		if (gotUUID) {
			// We've got a UUID to use
			ident->dataFormat = IFFormat_UUID;
			ident->data.uuid = uuid;
			ident->usesMd5 = 0;
		}
	}
	
	return self;
}

- (id) initWithZCodeFile: (NSString*) zcodeFile {
	self = [super init];
	
	if (self) {
		const unsigned char* bytes;
		int length;
		
		NSFileHandle* fh = [NSFileHandle fileHandleForReadingAtPath: zcodeFile];
		NSData* data = [fh readDataToEndOfFile];
		[fh closeFile];
		
		if ([data length] < 64) {
			// This file is too short to be a Z-Code file
			[self release];
			return nil;
		}
		
		bytes = [data bytes];
		length = [data length];
		
		if (bytes[0] == 'F' && bytes[1] == 'O' && bytes[2] == 'R' && bytes[3] == 'M') {
			// This is not a Z-Code file; it's possibly a blorb file, though
						
			// Try to interpret as a blorb file
			ZoomBlorbFile* blorbFile = [[ZoomBlorbFile alloc] initWithContentsOfFile: zcodeFile];
			
			if (blorbFile == nil) {
				[self release];
				return nil;
			}
			
			// See if we can get the ZCOD chunk
			data = [blorbFile dataForChunkWithType: @"ZCOD"];
			if (data == nil) {
				[blorbFile release];
				[self release];
				return nil;
			}
			
			if ([data length] < 64) {
				// This file is too short to be a Z-Code file
				[blorbFile release];
				[self release];
				return nil;
			}
			
			// Change to using the blorb data instead
			bytes = [[[data retain] autorelease] bytes];
			length = [data length];
			[blorbFile release];
		}
		
		if (bytes[0] > 8) {
			// This cannot be a Z-Code file
			[self release];
			return nil;
		}
		
		// Read the ID from the Z-Code data
		ident = IFID_Alloc();
		needsFreeing = YES;
		
		ident->format = ident->dataFormat = IFFormat_ZCode;
		
		memcpy(ident->data.zcode.serial, bytes + 0x12, 6);
		ident->data.zcode.release  = (((int)bytes[0x2])<<8)|((int)bytes[0x3]);
		ident->data.zcode.checksum = (((int)bytes[0x1c])<<8)|((int)bytes[0x1d]);
		ident->usesMd5 = 0;
		
		// Scan for the string 'UUID://' - use this as an ident for preference if it exists (and represents a valid UUID)
		struct IFMDUUID uuid;
		int x;
		BOOL gotUUID = NO;
		
		for (x=0; x<16; x++) uuid.uuid[x] = 0;
		
		for (x=0; x<length-48; x++) {
			if (bytes[x] == 'U' && bytes[x+1] == 'U' && bytes[x+2] == 'I' && bytes[x+3] == 'D' &&
				bytes[x+4] == ':' && bytes[x+5] == '/' && bytes[x+6] == '/') {
				// This might be a UUID section
				uuid = IFMD_ReadUUID((char*)(bytes + x + 7));
				
				// Check to see if we've got a UUID
				int y;
				gotUUID = NO;
				
				for (y=0; y<16; y++) {
					if (uuid.uuid[y] != 0) gotUUID = YES;
				}
				
				if (gotUUID) break;
			}
		}
		
		if (gotUUID) {
			// We've got a UUID to use
			ident->dataFormat = IFFormat_UUID;
			ident->data.uuid = uuid;
			ident->usesMd5 = 0;
		}
	}
	
	return self;
}

- (id) initWithData: (NSData*) genericGameData {
	self = [super init];
	
	if (self) {
		// IMPLEMENT ME: take MD5 of file
	}
	
	return self;
}

- (id) initWithIdent: (struct IFID*) idt {
	self = [super init];
	
	if (self) {
		ident = idt;
		needsFreeing = NO;
	}
	
	return self;
}

- (void) dealloc {
	if (needsFreeing) {
		IFID_Free(ident);
		free(ident);
	}
	
	[super dealloc];
}

- (struct IFMDIdent*) ident {
	return ident;
}

// = NSCopying =
- (id) copyWithZone: (NSZone*) zone {
	ZoomStoryID* newID = [[ZoomStoryID allocWithZone: zone] init];
	
	newID->ident = IFID_Alloc();
	IFIdent_Copy(newID->ident, ident);
	newID->needsFreeing = YES;
	
	return newID;
}

// = NSCoding =
- (void)encodeWithCoder:(NSCoder *)encoder {
	// Version might change later on
	int version = 1;
	
	[encoder encodeValueOfObjCType: @encode(int) at: &version];
	
	// General stuff (data format, MD5, etc)
	[encoder encodeValueOfObjCType: @encode(enum IFMDFormat) 
								at: &ident->dataFormat];
	[encoder encodeValueOfObjCType: @encode(IFMDByte)
								at: &ident->usesMd5];
	if (ident->usesMd5) {
		[encoder encodeArrayOfObjCType: @encode(IFMDByte)
								 count: 16
									at: ident->md5Sum];
	}
	
	switch (ident->dataFormat) {
		case IFFormat_ZCode:
			[encoder encodeArrayOfObjCType: @encode(IFMDByte)
									 count: 6
										at: ident->data.zcode.serial];
			[encoder encodeValueOfObjCType: @encode(int)
										at: &ident->data.zcode.release];
			[encoder encodeValueOfObjCType: @encode(int)
										at: &ident->data.zcode.checksum];
			break;
			
		case IFFormat_UUID:
			[encoder encodeArrayOfObjCType: @encode(unsigned char)
									 count: 16
										at: ident->data.uuid.uuid];
			break;
			
			
		default:
			/* No other formats are supported yet */
			break;
	}
}

- (id)initWithCoder:(NSCoder *)decoder {
	self = [super init];
	
	if (self) {
		ident = IFID_Alloc();
		needsFreeing = YES;
		
		// As above, but backwards
		int version;
		
		[decoder decodeValueOfObjCType: @encode(int) at: &version];
		
		if (version != 1) {
			// Only v1 decodes supported ATM
			[self release];
			
			NSLog(@"Tried to load a version %i ZoomStoryID (this version of Zoom supports only version 1)", version);
			
			return nil;
		}
		
		// General stuff (data format, MD5, etc)
		[decoder decodeValueOfObjCType: @encode(enum IFMDFormat) 
									at: &ident->dataFormat];
		ident->format = ident->dataFormat;
		[decoder decodeValueOfObjCType: @encode(IFMDByte)
									at: &ident->usesMd5];
		if (ident->usesMd5) {
			[decoder decodeArrayOfObjCType: @encode(IFMDByte)
									 count: 16
										at: ident->md5Sum];
		}
		
		switch (ident->dataFormat) {
			case IFFormat_ZCode:
				[decoder decodeArrayOfObjCType: @encode(IFMDByte)
										 count: 6
											at: ident->data.zcode.serial];
				[decoder decodeValueOfObjCType: @encode(int)
											at: &ident->data.zcode.release];
				[decoder decodeValueOfObjCType: @encode(int)
											at: &ident->data.zcode.checksum];
				break;
				
			case IFFormat_UUID:
				ident->format = IFFormat_ZCode;
				[decoder decodeArrayOfObjCType: @encode(unsigned char)
										 count: 16
											at: ident->data.uuid.uuid];
				break;
				
			default:
				/* No other formats are supported yet */
				break;
		}		
	}
	
	return self;
}

// = Hashing/comparing =
- (unsigned) hash {
	return [[self description] hash];
}

- (BOOL) isEqual: (id)anObject {
	if ([anObject isKindOfClass: [ZoomStoryID class]]) {
		ZoomStoryID* compareWith = anObject;
		
		if (IFID_Compare(ident, [compareWith ident]) == 0) {
			return YES;
		} else {
			return NO;
		}
	} else {
		return NO;
	}
}

- (NSString*) description {
	switch (ident->dataFormat) {
		case IFFormat_ZCode:
			return [NSString stringWithFormat: @"ZoomStoryID (ZCode): %i.%.6s.%04x",
				ident->data.zcode.release,
				ident->data.zcode.serial,
				ident->data.zcode.checksum];
			break;
			
		case IFFormat_UUID:
			return [NSString stringWithFormat: @"ZoomStoryID (UUID): %02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				ident->data.uuid.uuid[0],
				ident->data.uuid.uuid[1],
				ident->data.uuid.uuid[2],
				ident->data.uuid.uuid[3],
				ident->data.uuid.uuid[4],
				ident->data.uuid.uuid[5],
				ident->data.uuid.uuid[6],
				ident->data.uuid.uuid[7],
				ident->data.uuid.uuid[8],
				ident->data.uuid.uuid[9],
				ident->data.uuid.uuid[10],
				ident->data.uuid.uuid[11],
				ident->data.uuid.uuid[12],
				ident->data.uuid.uuid[13],
				ident->data.uuid.uuid[14],
				ident->data.uuid.uuid[15]];
			break;
			
		default:
			if (ident->usesMd5) {
				int x;
				
				NSMutableString* s = [NSMutableString string];
				NSAutoreleasePool* p = [[NSAutoreleasePool alloc] init];
				
				for (x=0; x<16; x++) {
					[s appendString: [NSString stringWithFormat: @"%02x", ident->md5Sum[x]]];
				}

				[p release];

				return [NSString stringWithFormat: @"ZoomStoryID (MD5): %@", s];
			} else {
				return [NSString stringWithFormat: @"ZoomStoryID (nonspecific)"];
			}
	}
}

@end
