//
//  ZpHugo.m
//  Hugo
//
//  Created by C.W. Betts on 11/5/22.
//

#import <Cocoa/Cocoa.h>
#import "ZpHugo.h"
#import <ZoomView/ZoomBlorbFile.h>
#import <ZoomPlugIns/ZoomBabel.h>

@implementation ZpHugo

+ (BOOL) canRunURL: (NSURL *)path {
	NSString* extn = [[path pathExtension] lowercaseString];
	
	if ([extn isEqualToString: @"hex"] || [extn isEqualToString: @"hdx"]) {
		return YES;
	}
	
	return NO;
}

+ (NSArray<NSString*>*)supportedFileTypes {
	return @[@"public.hugo", @"public.hugo.debug", @"hex", @"hdx", @"'Hugo'", @"'HugD'"];
}

+ (NSString*) pluginVersion {
	return [[NSBundle bundleForClass: [self class]] objectForInfoDictionaryKey: @"CFBundleVersion"];
}

+ (NSString*) pluginDescription {
	return @"Zoom Hugo PlugIn";
}

+ (NSString*) pluginAuthor {
	return @"C.W. \"Madd the Sane\" Betts";
}

- (NSImage *)logo {
	return [NSImage imageNamed:@"HUGO"];
}

- (id)initWithURL:(NSURL *)gameFile {
	if (self = [super initWithURL:gameFile]) {
		[self setClientPath: [[NSBundle bundleForClass: [self class]] pathForAuxiliaryExecutable: @"heglk"]];
	}
	return self;
}

#pragma mark - Code taken from Babel

static size_t number_of_hexadecimals_before_hyphen(const char *s, size_t len)
{
	size_t offset = 0;
	
	while (offset < len && isxdigit(s[offset])) {
		offset++;
	}
	
	if (offset == len || (offset < len && s[offset] == '-')) {
		return offset;
	}
	
	return 0;
}

/*! We look for the pattern XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (8-4-4-4-12)
 * where X is a number or A-F.
 *
 * One Hugo game, PAXLess, uses lowercase letters. The rest all use uppercase.
 */
static BOOL isUUID(const char *s)
{
	if (!(number_of_hexadecimals_before_hyphen(s, 9) == 8)) {
		return NO;
	}
	if (!(number_of_hexadecimals_before_hyphen(s+9, 5) == 4)) {
		return NO;
	}
	if (!(number_of_hexadecimals_before_hyphen(s+14, 5) == 4)) {
		return NO;
	}
	if (!(number_of_hexadecimals_before_hyphen(s+19, 5) == 4)) {
		return NO;
	}
	if (!(number_of_hexadecimals_before_hyphen(s+24, 12) == 12)) {
		return NO;
	}
	return YES;
}

//! The Hugo text obfuscation adds 20 to every character
static inline char hugo_decode(char c)
{
	int decoded_char = c - 20;
	if (decoded_char < 0) {
		decoded_char = decoded_char + 256;
	}
	return (char)decoded_char;
}

- (ZoomStoryID*) idForStory {
	NSData *file = [[NSData alloc] initWithContentsOfURL: self.gameURL];
	if (file == nil) {
		return nil;
	}

	char UUID_candidate[37];
	const char hyphen = '-' + 20;
	size_t extent = file.length;
	char ser[9];
	const char *story_file = (const char *)file.bytes;

	if (extent < 0x0B) {
		return nil;
	}

	char output[512];
	for (int i = 0; i < extent - 28; i++) {
		/* First we look for an obfuscated hyphen, '-' + 20 */
		/* We need to look 8 characters behind and 28 ahead */
		if (story_file[i] == hyphen && i >= 8 && extent - i >= 28 &&
			story_file[i+5] == hyphen &&
			story_file[i+10] == hyphen &&
			story_file[i+15] == hyphen) {
			for (int j = 0; j < 36; j++) {
				UUID_candidate[j] = hugo_decode(story_file[i + j - 8]);
			}
			if (isUUID(UUID_candidate)) {
				/* Found valid UUID at file offset i - 8 */
				NSString *output = [[NSString alloc] initWithBytes: UUID_candidate length: 36 encoding: NSASCIIStringEncoding];
				NSUUID *uuid = [[NSUUID alloc] initWithUUIDString: output];
				return [[ZoomStoryID alloc] initWithUUID: uuid];
			}
		}
	}
	
	/* Found no UUID in file. Construct legacy IFID */

	memcpy(ser, story_file+0x03, 8);
	ser[8] = 0;

	for (int j = 0; j < 8; j++) {
		if (!isalnum(ser[j])) {
			ser[j] = '-';
		}
	}

	NSString *preIFID = [NSString stringWithFormat: @"HUGO-%d-%02X-%02X-%s", story_file[0], story_file[1], story_file[2], ser];
	return [[ZoomStoryID alloc] initWithIdString: preIFID];
}

#pragma mark End of Code taken from Babel -


- (ZoomStory *)defaultMetadataWithError:(NSError *__autoreleasing  _Nullable *)outError {
	ZoomStory *meta = [[ZoomBabel alloc] initWithURL: self.gameURL].metadata;
	if (!meta) {
		return [super defaultMetadataWithError: outError];
	}
	return meta;
}

- (NSImage *)coverImage {
	ZoomBabel *babel = [[ZoomBabel alloc] initWithURL: self.gameURL];
	return [babel coverImage];
}

@end
