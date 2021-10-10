//
//  ZoomiFictionController+OldWebKit.m
//  Zoom
//
//  Created by C.W. Betts on 10/9/21.
//

#import <Foundation/Foundation.h>
#import "ZoomiFictionController.h"
#import "ZoomiFictionController+OldWebKit.h"

@implementation ZoomiFictionController (OldWebKit)

- (void)					webView: (WebView *)sender
	decidePolicyForNavigationAction: (NSDictionary *)actionInformation
							request:(NSURLRequest *)request
							  frame:(WebFrame *)frame
				   decisionListener:(id<WebPolicyDecisionListener>)listener {
	NSArray* archiveFiles = [NSArray arrayWithObjects: @"zip", @"tar", @"tgz", @"gz", @"bz2", @"z", nil];

	if ([[actionInformation objectForKey: WebActionNavigationTypeKey] intValue] == 0) {
#ifdef DEVELOPMENT_BUILD
		NSLog(@"Deciding policy for %@", [request URL]);
		NSLog(@"User-agent is %@", [ifdbView userAgentForURL: [request URL]]);
		NSLog(@"(Custom agent is %@)", [ifdbView customUserAgent]);
		NSLog(@"Header fields are %@", [request allHTTPHeaderFields]);
#endif
		
		// Get the URL to download
		NSURL* url = [request URL];
		
		NSString* fakeFile = [[NSTemporaryDirectory() stringByAppendingPathComponent: @"FakeDirectory"]
								stringByAppendingPathComponent: [[url path] lastPathComponent]];
		if ([self canPlayFile: fakeFile] || [archiveFiles containsObject: [[fakeFile pathExtension] lowercaseString]]) {
			// Use mirror.ifarchive.org, not www.ifarchive.org
			NSString* host = [url host];
			if ([host isEqualToString: @"www.ifarchive.org"]) {
				NSURLComponents *components = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:YES];
				components.host = @"mirror.ifarchive.org";
				url = components.URL;
			}
			
			// Download the specified file
			[activeDownload setDelegate: nil];
			activeDownload = nil;

			signpostId = nil;
			downloadUpdateList = NO;
			downloadPlugin = NO;
			
			activeDownload = [[ZoomDownload alloc] initWithUrl: url];
			[activeDownload setDelegate: self];
			[activeDownload startDownload];
			
			// Ignore the request
			[listener ignore];
			return;
		}
	}
	
	// Default is to use the request
	if ([NSURLConnection canHandleRequest: request]) {
		[listener use];
	} else {
		[listener ignore];
	}
}

- (void)           webView:(WebView *)sender
   decidePolicyForMIMEType:(NSString *)type
				   request:(NSURLRequest *)request
					 frame:(WebFrame *)frame
		  decisionListener:(id<WebPolicyDecisionListener>)listener {
	if (![WebView canShowMIMEType: type]) {
		[listener ignore];
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"Zoom cannot download this type of file";
		alert.informativeText = [NSString stringWithFormat: @"You have clicked on a download link that goes to a type of file that Zoom does not know how to handle. This could be because the file is a compressed file in a format that Zoom does not understand, or it could be because you have not installed the plug-in for this file type.\n\nYou can check for new plugins by using the 'Check for Updates' option in the Zoom menu.\n\nType \"%@\"", type];
		[alert addButtonWithTitle: @"Cancel"];
		[alert beginSheetModalForWindow: self.window completionHandler: ^(NSModalResponse returnCode) {
			
		}];

	} else {
		[listener use];
	}
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];
	
	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];
		
		[progressIndicator startAnimation: self];
	}
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];

	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];
		
		[progressIndicator startAnimation: self];
		
		// Cancel any running download
		if (activeDownload != nil && ![[[[frame dataSource] request] URL] isFileURL]) {
			[activeDownload setDelegate: nil];
			activeDownload = nil;
			[self hideDownloadWindow: 0.25];
		}
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];

	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];

		[progressIndicator stopAnimation: self];
	}
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];
	
	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];
		
		[progressIndicator stopAnimation: self];
		
		if (lastError == nil) lastError = [[ZoomJSError alloc] init];
		[lastError setLastError: [error localizedDescription]];
		
		switch ([error code]) {
			case 102:
				// Ignore these errors
				break;
				
			default:
				// Open the error page
				[[ifdbView mainFrame] loadRequest: [NSURLRequest requestWithURL: [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource: @"ifdb-failed"
																																		 ofType: @"html"]]]];
				break;
		}
	}
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame {
	[self updateBackForwardButtons];
	
	if (frame == [ifdbView mainFrame]) {
		NSString* url = [[[[frame dataSource] request] URL] absoluteString];
		if (url) [currentUrl setStringValue: url];
		
		[progressIndicator stopAnimation: self];
		
		if (lastError == nil) lastError = [[ZoomJSError alloc] init];
		[lastError setLastError: [error localizedDescription]];
		
		switch ([error code]) {
			case 102:
				// Ignore these errors
				break;
			
			default:
				// Open the error page
				[[ifdbView mainFrame] loadRequest: [NSURLRequest requestWithURL: [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource: @"ifdb-failed"
																																		 ofType: @"html"]]]];
				break;
		}
	}
}

- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject {
	// Attach the error object
	if (lastError == nil) {
		lastError = [[ZoomJSError alloc] init];
	}
	
	[[sender windowScriptObject] setValue: lastError
								   forKey: @"Errors"];
}

@end
