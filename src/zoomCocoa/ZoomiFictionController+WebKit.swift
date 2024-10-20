//
//  ZoomiFictionController+NewWebKit.swift
//  Zoom
//
//  Created by C.W. Betts on 10/30/21.
//

import Cocoa
import WebKit
import ZoomPlugIns.Swift
import ZoomPlugIns.ZoomStory
import ZoomPlugIns.ZoomResourceDrop
import ZoomPlugIns.ZoomMetadata
import ZoomPlugIns.ZoomStoryID
import ZoomPlugIns.ZoomGameInfoController
import ZoomPlugIns.ZoomNotesController
import ZoomPlugIns.ZoomPlugInManager
import ZoomPlugIns.ZoomPlugInController
import ZoomPlugIns.ZoomPlugIn
import ZoomView.Swift
import ZoomPlugIns.ifmetabase

extension ZoomiFictionController: WKNavigationDelegate {
	
	public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		updateBackForwardButtons()
		
		guard webView === ifdbView else {
			return
		}
		
		if let url = webView.url?.absoluteString {
			currentUrl?.stringValue = url
		}
		
		progressIndicator.stopAnimation(self)
		
		if lastError == nil {
			lastError = ZoomJSError()
		}
		lastError.lastError = error.localizedDescription
		
		let failedURL = Bundle.main.url(forResource: "ifdb-failed", withExtension: "html")!
		// Open the error page
		ifdbView.loadFileURL(failedURL, allowingReadAccessTo: failedURL.deletingLastPathComponent())
	}
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
		let archiveTypes = ["zip", "tar", "tgz", "gz", "bz2", "z"]
		
		guard webView === ifdbView else {
			return .cancel
		}
		
		if navigationAction.navigationType == .linkActivated, var url = navigationAction.request.url {
			let fakeURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(url.lastPathComponent)
			
			if canPlayFile(at: fakeURL) || archiveTypes.contains(fakeURL.pathExtension.lowercased()) {
				// Use mirror.ifarchive.org, not www.ifarchive.org
				if url.host == "www.ifarchive.org" {
					var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
					components.host = "mirror.ifarchive.org"
					url = components.url!
				}
				
				
				// TODO: implement?
//				if #available(macOS 12.0, *) {
//					decisionHandler(.download)
//				} else {
//					// Fallback on earlier versions
//				}

				// Download the specified file
				activeDownload?.delegate = nil
				activeDownload = nil
				
				signpostID = nil
				downloadUpdateList = false
				downloadPlugin = false
				
				activeDownload = ZoomDownload(from: url)
				activeDownload.delegate = self
				activeDownload.start()
				
				// Ignore the request
				return .cancel
			}
		}
		
		// Default is to use the request
		if NSURLConnection.canHandle(navigationAction.request) {
			return .allow
		} else {
			return .cancel
		}
	}
	
	public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		updateBackForwardButtons()

		guard webView === ifdbView else {
			return
		}
		
		if let url = webView.url?.absoluteString {
			currentUrl?.stringValue = url
		}
		
		progressIndicator.stopAnimation(self)
	}
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
		if !navigationResponse.canShowMIMEType {
			let alert = NSAlert()
			alert.messageText = NSLocalizedString("Zoom cannot download this type of file", comment: "Zoom cannot download this type of file")
			alert.informativeText = String(format: NSLocalizedString("Zoom cannot download this type of file Info: %@", comment: "Zoom cannot download this type of file Info, param is mime type or unknown"), navigationResponse.response.mimeType ?? "Unknown")
			alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel"))
			alert.beginSheetModal(for: window!) { response in
				// Do nothing
			}
			
			return .cancel
		} else {
			return .allow
		}
	}
	
	public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		updateBackForwardButtons()
		
		if webView === ifdbView {
			if let url = webView.url {
				currentUrl?.stringValue = url.absoluteString
			}
			
			progressIndicator.startAnimation(self)
		}
	}
}

extension ZoomiFictionController: WKScriptMessageHandlerWithReply {
	public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) async -> (Any?, String?) {
		if (message.body as AnyObject).isEqual("getError" as NSString)  {
			return (lastError?.lastError ?? "Unknown error!", nil)
		}
		return (nil, "Unknown message body received!")
	}
}
