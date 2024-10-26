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
/// For convenience sake, make the class that implements this protocol be a subclass of `ZoomPlugIn`.
@protocol ZoomStoryConverter <NSObject>

/// Convert a file to a usable format.
/// \param url The file to import.
/// \param handler The handler. \c newURL is a new URL after the conversion was successful or \c nil on failure.
/// If \c newURL is \c nil then \c error needs to be populated.
+ (void)convertStoryFileAtURL:(NSURL*)url completionHandler:(void(^)(NSURL *__nullable newURL, NSError*__nullable error))handler;

/// \c YES if the specified file URL is one that the plugin can convert
+ (BOOL) canConvertURL: (NSURL*) path;

/// Return an array of file types that an \c NSOpenPanel can select from.
///
/// This may be UTIs, file extensions, or OSTypes (Created by \c NSFileTypeForHFSTypeCode or similar).
@property (class, readonly, copy) NSArray<NSString*> *supportedConverterFileTypes;

@optional

/// Return an array of content types that an \c NSOpenPanel can select from.
///
/// If your converter doesn't implement this method, ZoomPlugInManager will take the
/// class property \c supportedConverterFileTypes and creates <code>UTType</code>s from the
/// parsed extensions, UTIs, and OSTypes.
/// \note Unless the type identifiers are present in Zoom's \b Info.plist or declared by another application,
/// <code>+[UTType typeWithIdentifier:]</code> \e will fail and <code>+[UTType importedTypeWithIdentifier:]</code>
/// will complain. The best way to handle this is to \e not implement this class property and instead
/// let ZoomPlugInManager create them from your own \c supportedFileTypes .
@property (class, readonly, copy) NSArray<UTType*> *supportedConverterContentTypes;

@end

NS_ASSUME_NONNULL_END

#endif
