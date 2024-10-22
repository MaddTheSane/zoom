//
//  ZoomPlugInInfo.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class ZoomDownload;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, ZoomPlugInStatus) {
	/// Installed plugin
	ZoomPlugInInstalled NS_SWIFT_NAME(installed),
	/// Installed plugin that has been disabled
	ZoomPlugInDisabled NS_SWIFT_NAME(disabled),
	/// Installed plugin, update to be installed
	ZoomPlugInUpdated NS_SWIFT_NAME(updated),
	/// Downloaded plugin available to install
	ZoomPlugInDownloaded NS_SWIFT_NAME(downloaded),
	/// Update available to download
	ZoomPluginUpdateAvailable NS_SWIFT_NAME(updateAvailable),
	/// Not yet installed, available to download
	ZoomPlugInNew NS_SWIFT_NAME(new),
	/// Marked as having an update, but it failed to download
	ZoomPlugInDownloadFailed NS_SWIFT_NAME(downloadFailed),
	/// Downloaded, but the installation failed for some reason
	ZoomPlugInInstallFailed NS_SWIFT_NAME(installFailed),
	/// Currently downloading
	ZoomPlugInDownloading NS_SWIFT_NAME(downloading),
	/// Unknown status
	ZoomPlugInNotKnown NS_SWIFT_NAME(notKnown),
};

///
/// Class representing information about a known plugin
///
@interface ZoomPlugInInfo : NSObject<NSCopying>

// Initialisation
/// Initialise with an existing plugin bundle
- (nullable instancetype) initWithBundleFilename: (NSString*) bundle;
/// Initialise with the contents of a particular plist dictionary
- (nullable instancetype) initFromPList: (nullable NSDictionary<NSString*, id>*) plist;

// Retrieving the information
/// The name of this plugin
@property (readonly, copy) NSString *name;
/// The author of the plugin bundle
@property (readonly, copy) NSString *author;
/// The version of the plugin bundle
@property (readonly, copy) NSString *version;
/// The author of the interpreter in the plugin
@property (readonly, copy) NSString *interpreterAuthor;
/// The version of the interpreter in the plugin
@property (readonly, copy) NSString *interpreterVersion;
/// The image that represents this plugin
@property (nullable, readonly, copy) NSImage *image;
/// Where this plugin is located
@property (nullable, readonly, strong) NSURL *location;
/// The URL for updates to this plugin
@property (nullable, readonly, strong) NSURL *updateUrl;
/// The status for this plugin
@property ZoomPlugInStatus status;
/// The MD5 for the archive containing the plugin
@property (nullable, readonly, copy) NSData *md5;
/// Updates the status for this plugin
- (void) setStatus: (ZoomPlugInStatus) status;

/// The plugin info for any known updates to this plugin
@property (nullable, strong) ZoomPlugInInfo *updateInfo;

/// The download for the update for this plugin
@property (nullable, strong) ZoomDownload *download;

@end

NS_ASSUME_NONNULL_END
