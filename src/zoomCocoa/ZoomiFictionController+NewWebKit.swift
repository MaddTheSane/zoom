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
		
	}
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		
	}
	
	public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		
	}
	
	public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		if webView === ifdbNewView {
			if let url = webView.url {
				currentUrl.stringValue = url.absoluteString
			}
			
			progressIndicator.startAnimation(self)
		}
	}
	
	@available(macOS 12.0, *)
	public func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
		
	}
}
