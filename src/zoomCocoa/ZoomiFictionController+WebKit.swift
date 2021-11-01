//
//  ZoomiFictionController+NewWebKit.swift
//  Zoom
//
//  Created by C.W. Betts on 10/30/21.
//

import Cocoa
import WebKit

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
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		let archiveTypes = ["zip", "tar", "tgz", "gz", "bz2", "z"]
		
		guard webView === ifdbView else {
			decisionHandler(.cancel)
			return
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
				
				activeDownload = ZoomDownload(url: url)
				activeDownload.delegate = self
				activeDownload.start()
				
				// Ignore the request
				decisionHandler(.cancel)
				
				return
			}
		}
		
		// Default is to use the request
		if NSURLConnection.canHandle(navigationAction.request) {
			decisionHandler(.allow)
		} else {
			decisionHandler(.cancel)
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
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		if !navigationResponse.canShowMIMEType {
			decisionHandler(.cancel)

			let alert = NSAlert()
			alert.messageText = "Zoom cannot download this type of file"
			alert.informativeText = """
You have clicked on a download link that goes to a type of file that Zoom does not know how to handle. This could be because the file is a compressed file in a format that Zoom does not understand, or it could be because you have not installed the plug-in for this file type.

You can check for new plugins by using the 'Check for Updates' option in the Zoom menu.

Type "\(navigationResponse.response.mimeType ?? "Unknown")"
"""
			alert.addButton(withTitle: "Cancel")
			alert.beginSheetModal(for: window!) { response in
				// Do nothing
			}
		} else {
			decisionHandler(.allow)
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
	
	@available(macOS 12.0, *)
	public func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
		download.delegate = self
	}
	
	// TODO: Revive ZoomJSError functionality. Maybe use WKUserScript?
}

@available(macOS 12.0, *)
extension ZoomiFictionController: WKDownloadDelegate {
	public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
		return nil
	}
}
