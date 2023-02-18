//
//  ZpTadsTwo.m
//  Tads2
//
//  Created by C.W. Betts on 2/18/23.
//

#import "ZpTadsTwo.h"
#import <ZoomPlugIns/ZoomBabel.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation ZpTadsTwo
{
	ZoomBabel *ourBabel;
}

+ (NSString*) pluginVersion {
	return [[NSBundle bundleForClass: [self class]] objectForInfoDictionaryKey: @"CFBundleVersion"];
}

+ (NSString*)pluginDescription
{
	return @"Zoom TADS 2 PlugIn";
}

+ (NSString *)pluginAuthor
{
	return @"Andrew Hunter";
}

+ (NSArray<NSString*>*)supportedFileTypes {
	return @[@"org.tads.tads2-game", @"gam", @"'TADG'"];
}

+ (NSArray<UTType *> *)supportedContentTypes {
	return @[[UTType importedTypeWithIdentifier:@"org.tads.tads2-game"]];
}

+ (BOOL)canRunURL:(NSURL *)path
{
	NSString* extn = [[path pathExtension] lowercaseString];
	if ([extn isEqualToString:@"gam"]) {
		return YES;
	}
	return NO;
}

- (id)initWithURL:(NSURL *)gameFile
{
	if (self = [super initWithURL:gameFile]) {
		
	}
	return self;
}

- (ZoomStoryID *)idForStory
{
	NSData *dat = [NSData dataWithContentsOfURL:self.gameURL];
	if (!dat) {
		return nil;
	}
	return [[ZoomStoryID alloc] initWithData:dat type:@"TADS2"];
}

- (ZoomBabel*)babel
{
	if (ourBabel) {
		return ourBabel;
	}
	ourBabel = [[ZoomBabel alloc] initWithURL:self.gameURL];
	return ourBabel;
}

- (NSImage *)logo {
	return [NSImage imageNamed:@"TADS"];
}


@end
