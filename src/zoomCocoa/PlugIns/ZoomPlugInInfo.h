//
//  ZoomPlugInInfo.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomDownload.h>

typedef NS_ENUM(int, ZoomPlugInStatus) {
	ZoomPlugInInstalled,									//!< Installed plugin
	ZoomPlugInDisabled,										//!< Installed plugin that has been disabled
	ZoomPlugInUpdated,										//!< Installed plugin, update to be installed
	ZoomPlugInDownloaded,									//!< Downloaded plugin available to install
	ZoomPluginUpdateAvailable,								//!< Update available to download
	ZoomPlugInNew,											//!< Not yet installed, available to download
	ZoomPlugInDownloadFailed,								//!< Marked as having an update, but it failed to download
	ZoomPlugInInstallFailed,								//!< Downloaded, but the installation failed for some reason
	ZoomPlugInDownloading,									//!< Currently downloading
	ZoomPlugInNotKnown,										//!< Unknown status
};

///
/// Class representing information about a known plugin
///
@interface ZoomPlugInInfo : NSObject<NSCopying> {
	NSString* image;										// The filename of an image for this plugin
	NSString* name;											// The name of the plugin
	NSString* author;										// The author of the plugin
	NSString* interpreterAuthor;							// The author of the interpreter
	NSString* version;										// The version number of the plugin
	NSString* interpreterVersion;							// The version number of the interpreter contained in the plugin
	NSURL* location;										// The location of this plugin
	NSData* md5;											// The MD5 for the plugin archive
	NSURL* updateUrl;										// The URL that should be consulted for updates to this plugin
	ZoomPlugInStatus status;								// The status for this plugin
	
	ZoomPlugInInfo* updated;								// The updated information for this plugin, if check for updates has found one
	ZoomDownload* updateDownload;							// The active download for the update
}

// Initialisation
- (id) initWithBundleFilename: (NSString*) bundle;			//!< Initialise with an existing plugin bundle
- (id) initFromPList: (NSDictionary<NSString*, id>*) plist;	//!< Initialise with the contents of a particular plist dictionary

// Retrieving the information
@property (readonly, copy) NSString *name;					//!< The name of this plugin
@property (readonly, copy) NSString *author;				//!< The author of the plugin bundle
@property (readonly, copy) NSString *version;				//!< The version of the plugin bundle
@property (readonly, copy) NSString *interpreterAuthor;		//!< The author of the interpreter in the plugin
@property (readonly, copy) NSString *interpreterVersion;	//!< The version of the interpreter in the plugin
@property (readonly, copy) NSString *imagePath;				//!< The path to an image that represents this plugin
@property (readonly, strong) NSURL *location;				//!< Where this plugin is located
@property (readonly, strong) NSURL *updateUrl;				//!< The URL for updates to this plugin
@property ZoomPlugInStatus status;							//!< The status for this plugin
@property (readonly, copy) NSData *md5;						//!< The MD5 for the archive containing the plugin
- (void) setStatus: (ZoomPlugInStatus) status;				//!< Updates the status for this plugin

@property (strong) ZoomPlugInInfo *updateInfo;				//!< The plugin info for any known updates to this plugin

@property (strong) ZoomDownload *download;					//!< The download for the update for this plugin

@end
