//
//  ZoomDownload.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ZoomDownloadDelegate;

///
/// Class that handles the download and unarchiving of files, such as plugin updates
///
@interface ZoomDownload : NSObject {
	NSURL* url;													// Where to download from
	__weak id<ZoomDownloadDelegate> delegate;					// The download delegate
	NSData* md5;												// The expected MD5 for the downloaded file
	
	NSURLConnection* connection;								// The connection that the download will be loaded via
	NSFileHandle* downloadFile;									// A file handle containing the file that we're downloading
	NSString* tmpFile;											// The file that the download is going to
	NSString* tmpDirectory;										// The directoruy that the download was unarchived to
	NSString* suggestedFilename;								// The filename suggested for this download in the response
	long long expectedLength;									// The expected length of the download
	long long downloadedSoFar;									// The amount downloaded so far
	
	NSTask* task;												// The main unarchiving task
	NSMutableArray* subtasks;									// The set of subtasks that are currently running
}

// Initialisation
//! Prepares to download the specified URL
- (id) initWithUrl: (NSURL*) url;
//! The download delegate
@property (weak) id<ZoomDownloadDelegate> delegate;
//! Removes the temporary directory used for downloads (ie, when terminating)
+ (void) removeTemporaryDirectory;
//! Sets the expected MD5 for the downloaded file
- (void) setExpectedMD5: (NSData*) md5;

@property (copy) NSData *expectedMD5;

// Starting the download
//! Starts the download running
- (void) startDownload;

// Getting the download directory
//! The url for this download
@property (readonly, strong) NSURL *url;
//! The temporary directory where the download was placed (deleted when this object is dealloced)
@property (readonly, copy) NSString *downloadDirectory;
//! The filename suggested for this download in the response
@property (readonly, copy) NSString *suggestedFilename;

@end

///
/// Delegate methods for the download class
///
@protocol ZoomDownloadDelegate <NSObject>
@optional

//! A download is starting
- (void) downloadStarting: (ZoomDownload*) download;
//! The download has completed
- (void) downloadComplete: (ZoomDownload*) download;
//! The download failed for some reason
- (void) downloadFailed: (ZoomDownload*) download
				 reason: (NSString*) reason;

//! The download is connecting
- (void) downloadConnecting: (ZoomDownload*) download;
//! The download is reading data
- (void) downloading: (ZoomDownload*) download;
//! Value between 0 and 1 indicating how far the download has progressed
- (void) download: (ZoomDownload*) download
		completed: (float) complete;
//! Indicates that a .zip or .tar file is being decompressed
- (void) downloadUnarchiving: (ZoomDownload*) download;

@end
