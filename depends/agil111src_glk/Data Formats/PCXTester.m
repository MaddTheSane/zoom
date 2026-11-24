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
		fprintf(stderr, "Usage: %s path/to/file.pcx [additional-path]\n", *argv);
		return EXIT_FAILURE;
	}
	int exitStatus = EXIT_SUCCESS;
	for (int i = 1; i < argc; i++) @autoreleasepool {
		NSError *err = nil;
		NSURL *theURL = [[NSURL alloc] initFileURLWithFileSystemRepresentation:argv[i] isDirectory: NO relativeToURL: nil];
		PCXDecoder *aDec = [[PCXDecoder alloc] initWithFileAtURL:theURL error:&err];
		if (!aDec) {
			NSLog(@"path %@, error: %@", theURL.path, err);
			exitStatus = EXIT_FAILURE;
			continue;
		}
		if (![aDec parseWithError:&err]) {
			NSLog(@"path %@, error: %@", theURL.path, err);
			exitStatus = EXIT_FAILURE;
			continue;
		}
		NSURL *outURL = [theURL.URLByDeletingPathExtension URLByAppendingPathExtension:@"tiff"];
		NSData *dat = [aDec dataRepresentation];
		if (![dat writeToURL:outURL options:0 error:&err]) {
			NSLog(@"export path %@, error: %@", outURL.path, err);
		}
	}
	
	return exitStatus;
}
