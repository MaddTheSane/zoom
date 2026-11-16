//
//  ZoomConnector.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on 30/08/2004.
//  Copyright 2004 Andrew Hunter. All rights reserved.
//

#include <unistd.h>

#import "ZoomConnector.h"


@implementation ZoomConnector {
	NSConnection* connection;
	/// The views waiting for a server, by the server's process identifier
	NSMutableDictionary<NSNumber*, ZoomView*>* waitingViews;
}

#pragma mark - The shared connector

+ (ZoomConnector*) sharedConnector {
	static ZoomConnector* sharedConnector = nil;
	
	if (sharedConnector == nil) {
		sharedConnector = [[[self class] alloc] init];
	}
	
	return sharedConnector;
}

#pragma mark - Initialisation

- (id) init {
	self = [super init];
	
	if (self) {
		// Create the connection that we'll use to allow ZoomServer processes to connect to us
		// (Originally, this was created by the ZoomServer processes themselves, but there is a limit to the
		// number of Mach ports that can be created in OS X. Exceeding the limit creates a kernel panic - an
		// OS X bug, but one we really don't want to provoke if possible)
		//
		// Unlikely that anyone ever encountered this: you need ~200-odd running games before things go
		// kaboom.
		NSString* connectionName = [NSString stringWithFormat: @"Zoom-%i", getpid()];
		NSPort* port = [NSMachPort port];
		
		connection = [NSConnection connectionWithReceivePort: port
													sendPort: port];
		[connection setRootObject: self];
		[connection addRunLoop: [NSRunLoop currentRunLoop]];
		if (![connection registerName: connectionName]) {
			NSLog(@"Uh-oh: failed to register a connection. Games will probably fail to start");
		}
		
		waitingViews = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void) dealloc {
	[connection registerName: nil];
}

#pragma mark - Connecting views to Z-Machines

- (void) addView: (ZoomView*) view waitingForServerWithProcessIdentifier: (int) processIdentifier {
	[self removeView: view];
	[waitingViews setObject: view
					 forKey: @(processIdentifier)];
}

- (void) removeView: (ZoomView*) view {
	[waitingViews removeObjectsForKeys: [waitingViews allKeysForObject: view]];
}

- (byref id<ZDisplay>) connectToDisplay: (in byref id<ZMachine>) zMachine
							fromProcess: (int) processIdentifier {
	// Get the view that launched this server
	ZoomView* whichView = [waitingViews objectForKey: @(processIdentifier)];
	if (whichView == nil) {
		NSLog(@"WARNING: attempt to connect to a display by a server that no view is waiting for");
		return nil;
	}
	
	// Remove from the list of waiting views
	[waitingViews removeObjectForKey: @(processIdentifier)];
	
	// Notify the view that it's gained a Z-Machine
	[[NSRunLoop currentRunLoop] performSelector: @selector(setZMachine:)
										 target: whichView
									   argument: zMachine
										  order: 16
										  modes: @[NSDefaultRunLoopMode]];
	
	// Using the runloop there stops the server from receiving any messages before this call returns.
	// As things currently stand, that basically ensures that this call returns at all before the Z-Machine
	// is terminated. This is non-critical as things stand, though.
	
	// We're done
	return whichView;
}

@end
