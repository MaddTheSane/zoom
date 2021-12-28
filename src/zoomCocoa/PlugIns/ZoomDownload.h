//
//  ZoomDownload.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class ZoomDownload;

/// Delegate methods for the download class
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

@class XADHandle;
extern BOOL XADOutputToHandleBytesLengthError(XADHandle *handle, const void *bytes, int length, NSError **error) /*NS_SWIFT_NAME(XADOutputTo(_:bytes:length:)) __attribute__((swift_error(nonnull_error)))*/ NS_REFINED_FOR_SWIFT;

NS_ASSUME_NONNULL_END
