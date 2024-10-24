//
//  PCXDecoder.m
//  agil
//
//  Created by C.W. Betts on 1/6/23.
//

#import "PCXDecoder.h"

int main(int argc, char *argv[])
{
	if (argc < 2) {
		return EXIT_FAILURE;
	}
	@autoreleasepool {
		NSError *err = nil;
		NSURL *theURL = [[NSURL alloc] initFileURLWithFileSystemRepresentation:argv[1] isDirectory: NO relativeToURL: nil];
		PCXDecoder *aDec = [[PCXDecoder alloc] initWithFileAtURL:theURL error:&err];
		if (!aDec) {
			NSLog(@"%@", err);
			return EXIT_FAILURE;
		}
		NSURL *outURL = [theURL.URLByDeletingPathExtension URLByAppendingPathExtension:@"tiff"];
		NSData *dat = [aDec dataRepresentation];
		[dat writeToURL:outURL atomically:YES];
	}
	
	return EXIT_SUCCESS;
}
