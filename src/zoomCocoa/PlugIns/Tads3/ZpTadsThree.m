//
//  ZpTadsTwo.m
//  Tads2
//
//  Created by C.W. Betts on 2/18/23.
//

#import "ZpTadsThree.h"
#import <ZoomPlugIns/ZoomBabel.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation ZpTadsThree
{
	ZoomBabel *ourBabel;
}

+ (NSString*) pluginVersion {
	return [[NSBundle bundleForClass: [self class]] objectForInfoDictionaryKey: @"CFBundleVersion"];
}

+ (NSString*)pluginDescription
{
	return @"Zoom TADS 3 PlugIn";
}

+ (NSString *)pluginAuthor
{
	return @"Andrew Hunter";
}

+ (NSArray<NSString*>*)supportedFileTypes {
	return @[@"org.tads.tads3-game", @"t3", @"t3x", @"'.T3X'"];
}

+ (BOOL)canRunURL:(NSURL *)path
{
	NSString* extn = [[path pathExtension] lowercaseString];
	if ([extn isEqualToString:@"t3"] || [extn isEqualToString:@"t3x"]) {
		return YES;
	}
	return NO;
}

- (id)initWithURL:(NSURL *)gameFile
{
	if (self = [super initWithURL:gameFile]) {
		[self setClientPath: [[NSBundle bundleForClass: [self class]] pathForAuxiliaryExecutable: @"tads-3"]];
	}
	return self;
}

- (ZoomStoryID *)idForStory
{
	NSData *dat = [NSData dataWithContentsOfURL:self.gameURL];
	if (!dat) {
		return nil;
	}
	return [[ZoomStoryID alloc] initWithData:dat type:@"TADS3"];
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
