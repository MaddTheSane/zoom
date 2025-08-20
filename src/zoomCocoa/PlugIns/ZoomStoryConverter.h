//
//  ZoomImporter.h
//  ZoomCocoa
//
//  Created by C.W. Betts on 10/23/24.
//

#ifndef __ZOOMPLUGINS_ZOOMIMPORTER_H__
#define __ZOOMPLUGINS_ZOOMIMPORTER_H__

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class UTType;

/// Protocol for files that need conversion before the plug-in can actually use them.
///
/// For convenience sake, the class that implements this protocol must be a subclass of `ZoomPlugIn`.
@protocol ZoomStoryConverter <NSObject>

/// Convert a file to a usable format.
/// \param url The file to import.
/// \param handler The handler. `newURL` is a URL of the created file after the conversion was successful or `nil` on failure.
/// If `newURL` is `nil`, then `error` needs to be populated.
///
/// If you're using Swift, be prepared to have this called on the non-main thread if you implement this using `async`.
+ (void)convertStoryFileAtURL:(NSURL*)url completionHandler:(void(^)(NSURL *__nullable newURL, NSError*__nullable error))handler;

/// `YES` if the specified file URL is one that the plugin can convert.
+ (BOOL) canConvertURL: (NSURL*) path;

/// Return an array of file types that an `NSOpenPanel` can select from.
///
/// This may be UTIs, file extensions, or OSTypes (Created by `NSFileTypeForHFSTypeCode()` or similar).
@property (class, readonly, copy) NSArray<NSString*> *supportedConverterFileTypes;

@optional

/// Return an array of content types that an `NSOpenPanel` can select from.
///
/// If your converter doesn't implement this method, ZoomPlugInManager will take the
/// class property `+supportedConverterFileTypes` and creates `UTType`s from the
/// parsed extensions, UTIs, and OSTypes.
///
/// - Warning: Unless the type identifiers are present in Zoom's **Info.plist** or declared by another application,
/// `+[UTType typeWithIdentifier:]` *will* fail and `+[UTType importedTypeWithIdentifier:]`
/// will complain. The best way to handle this is to *not* implement this class property and instead
/// let ZoomPlugInManager create them from your own ``+supportedConverterFileTypes``.
@property (class, readonly, copy) NSArray<UTType*> *supportedConverterContentTypes;

@end

NS_ASSUME_NONNULL_END

#endif
