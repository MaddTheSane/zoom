//
//  ZoomSkein.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomSkeinItem.h>
#import <ZoomView/ZoomViewProtocols.h>

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const ZoomSkeinChangedNotification NS_SWIFT_NAME(ZoomSkein.changedNotification);

@interface ZoomSkein : NSObject <ZoomViewOutputReceiver>

/// Retrieving the root skein item
@property (readonly, strong) ZoomSkeinItem *rootItem;

@property (strong) ZoomSkeinItem *activeItem;

#pragma mark Acting as a Zoom output receiver
- (void) inputCommand:   (NSString*) command;
- (void) inputCharacter: (NSString*) character;
- (void) outputText:     (NSString*) outputText;
- (void) zoomWaitingForInput;
- (void) zoomInterpreterRestart;

/// Notifying of changed
- (void) zoomSkeinChanged;

/// Removing temporary items
- (void) removeTemporaryItems: (int) maxTemps;

/// Creating a Zoom input receiver
+ (nullable id<ZoomViewInputSource>) inputSourceFromSkeinItem: (ZoomSkeinItem*) item1
													   toItem: (ZoomSkeinItem*) item2;

#pragma mark Annotation lists
@property (nonatomic, readonly, copy, null_unspecified) NSArray<NSString*> *annotations;
- (NSMenu*)  populateMenuWithAction: (SEL) action
							 target: (id) target;
- (void)	 populatePopupButton: (NSPopUpButton*) button;
- (null_unspecified NSArray<ZoomSkeinItem*>*) itemsWithAnnotation: (NSString*) annotation;

#pragma mark Converting to strings/other file formats
- (NSString*) transcriptToPoint: (nullable ZoomSkeinItem*) item;
- (NSString*) recordingToPoint: (nullable ZoomSkeinItem*) item;

@end

#pragma mark - Dealing with/creating XML data

extern NSErrorDomain const ZoomSkeinXMLParserErrorDomain;
typedef NS_ERROR_ENUM(ZoomSkeinXMLParserErrorDomain, ZoomSkeinXMLError) {
	ZoomSkeinXMLErrorParserFailed,
	ZoomSkeinXMLErrorNoRootSkein,
	ZoomSkeinXMLErrorNoRootNodeID,
	ZoomSkeinXMLErrorProgrammerIsASpoon,
	ZoomSkeinXMLErrorNoRootNode,
};

@interface ZoomSkein(ZoomSkeinXML)

/// Creates an XML representation of the Skein.
- (NSString*) xmlData;

- (BOOL) parseXmlData: (NSData*) data error: (NSError**) error;
- (BOOL) parseXMLContentsAtURL: (NSURL*) url error: (NSError**) error;

@end

NS_ASSUME_NONNULL_END
