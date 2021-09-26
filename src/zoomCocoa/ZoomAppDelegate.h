//
//  ZoomAppDelegate.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Tue Oct 14 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <ZoomView/ZoomProtocol.h>
#import "ZoomPreferenceWindow.h"
#import <ZoomPlugIns/ZoomMetadata.h>
#import <ZoomPlugIns/ZoomStory.h>
#import "ZoomiFictionController.h"
#import <ZoomView/ZoomView.h>
#import "ZoomLeopard.h"

@class SUUpdater;
@interface ZoomAppDelegate : NSObject <NSApplicationDelegate, NSOpenSavePanelDelegate> {
	ZoomPreferenceWindow* preferencePanel;
	IBOutlet SUUpdater* updater;
	
	NSMutableArray<ZoomMetadata*>* gameIndices;
	id<ZoomLeopard> leopard;
}

@property (readonly, copy) NSArray<ZoomMetadata*> *gameIndices;
- (ZoomStory*) findStory: (ZoomStoryID*) gameID;
- (ZoomMetadata*) userMetadata;

@property (readonly, copy) NSString *zoomConfigDirectory;
@property (readonly, strong) id<ZoomLeopard> leopard;

- (IBAction) fixedOpenDocument: (id) sender;
- (IBAction) showPluginManager: (id) sender;
- (IBAction) checkForUpdates: (id) sender;

@end
