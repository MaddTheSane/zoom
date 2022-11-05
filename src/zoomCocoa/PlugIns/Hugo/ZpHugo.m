//
//  ZpHugo.m
//  Hugo
//
//  Created by C.W. Betts on 11/5/22.
//

#import <Cocoa/Cocoa.h>
#import "ZpHugo.h"
#import <ZoomView/ZoomBlorbFile.h>

@implementation ZpHugo

+ (BOOL) canRunURL: (NSURL *)path {
	NSString* extn = [[path pathExtension] lowercaseString];
	
	if ([extn isEqualToString: @"hex"]) return YES;
	
	return [super canRunURL: path];
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

- (id)initWithURL:(NSURL *)gameFile {
	if (self = [super initWithURL:gameFile]) {
		[self setClientPath: [[NSBundle bundleForClass: [self class]] pathForAuxiliaryExecutable: @"heglk"]];
	}
	return self;
}

- (ZoomStoryID*) idForStory {
	return nil;
}

@end
