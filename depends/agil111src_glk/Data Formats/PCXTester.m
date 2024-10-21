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
		NSURL *theURL = [[NSURL alloc] initFileURLWithFileSystemRepresentation:argv[1] isDirectory: NO relativeToURL: nil];
		PCXDecoder *aDec = [[PCXDecoder alloc] initWithFileAtURL:theURL error:NULL];
		NSURL *outURL = [theURL.URLByDeletingPathExtension URLByAppendingPathExtension:@"tiff"];
		NSData *dat = [aDec TIFFRepresentation];
		[dat writeToURL:outURL atomically:YES];
	}
	
	return EXIT_SUCCESS;
}
