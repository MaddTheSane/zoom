//
//  ZoomDownload.swift
//  ZoomPlugIns
//
//  Created by C.W. Betts on 12/15/21.
//

import Foundation
import CryptoKit
import ZoomPlugIns.ZoomDownload

private var localDownloadDirectory: URL = {
	var downloadDir: URL
	if #available(macOSApplicationExtension 13.0, *) {
		downloadDir = URL.temporaryDirectory
	} else {
		let tempDir = NSTemporaryDirectory()
		downloadDir = URL(fileURLWithPath: tempDir)
	}
	downloadDir.appendPathComponent("Zoom-Downloads-\(getpid())")

	return downloadDir
}()
private var lastDownloadID = 0

private func fullExtension(forFilename filename: String) -> String? {
	let filenameNS = filename as NSString
	let fileextension = filenameNS.pathExtension
	let withoutExtensions = filenameNS.deletingPathExtension
	
	guard fileextension.count > 0 else {
		return nil
	}
	
	let extraExtension = fullExtension(forFilename: withoutExtensions)
	if let extraExtension = extraExtension as NSString? {
		return extraExtension.appendingPathExtension(fileextension)
	} else {
		return fileextension
	}
}

/// Class that handles the download and unarchiving of files, such as plugin updates
@objcMembers
public class ZoomDownload: NSObject, URLSessionDataDelegate, URLSessionDelegate, URLSessionDownloadDelegate {
	/// The download delegate
	public weak var delegate: ZoomDownloadDelegate?
	
	private var session: URLSession!
	
	private var dataTask: URLSessionDataTask?
	private var downloadTask: URLSessionDownloadTask?
	
	/// The url for this download
	public let url: URL
	
	/// Sets the expected MD5 for the downloaded file
	public var expectedMD5: Data?
	/// The main unarchiving task
	private var task: Process?
	/// The set of subtasks that are currently running
	private var subtasks: [Process]?
	
	/// The filename suggested for this download in the response
	public private(set) var suggestedFilename: String?
	/// The temporary directory where the download was placed (deleted when this object is dealloced)
	public private(set) var downloadDirectory: URL?
	
	private var tmpFile: URL?
	
	/// Prepares to download the specified URL
	@objc(initWithURL:) public init?(from url: URL?) {
		guard let url else {
			return nil
		}
		self.url = url
		let config = URLSessionConfiguration.ephemeral
		config.networkServiceType = .background
		super.init()
		session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}
	
	/// Removes the temporary directory used for downloads (ie, when terminating)
	public class func removeTemporaryDirectory() {
		do {
			guard try localDownloadDirectory.checkResourceIsReachable() else {
				return
			}
			try FileManager.default.removeItem(at: localDownloadDirectory)
		} catch {
			
		}
	}
	
	// MARK: - Starting the download
	
	/// Starts the download running
	@objc(startDownload) public func start() {
		// Do nothing if this download is already running
		guard dataTask == nil, downloadTask == nil else {
			return
		}
		
		// Let the delegate know
		delegate?.downloadStarting?(self)
		
		NSLog("Downloading: %@", url as NSURL)
		
		// Create a connection to download the specified URL
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
		
		dataTask = session.dataTask(with: request)
		dataTask?.taskDescription = "Zoom: Downloading \(url.lastPathComponent)"
	}
	
	deinit {
		// Finished with notifications
		NotificationCenter.default.removeObserver(self)
		
		// Delete the temporary file
		if let tmpFile = tmpFile {
			try? FileManager.default.removeItem(at: tmpFile)
		}
		
		// Delete the temporary directory
		if let downloadDirectory = downloadDirectory {
			try? FileManager.default.removeItem(at: downloadDirectory)
		}
		
		// Kill any tasks
		if let task, task.isRunning {
			task.interrupt()
			task.terminate()
		}
		
		if let subtasks {
			for sub in subtasks {
				if sub.isRunning {
					sub.interrupt()
					sub.terminate()
				}
			}
		}
	}
	
	private func createDownloadDirectory() {
		do {
			let vals = try localDownloadDirectory.resourceValues(forKeys: [.isDirectoryKey])
			if !(vals.isDirectory ?? false) {
				var tmpDD = localDownloadDirectory
				tmpDD.deleteLastPathComponent()
				tmpDD.appendPathComponent("\(localDownloadDirectory.lastPathComponent)-1")
				localDownloadDirectory = tmpDD
				createDownloadDirectory()
			}
		} catch {
			try? FileManager.default.createDirectory(at: localDownloadDirectory, withIntermediateDirectories: false, attributes: nil)
		}
	}
	
	// MARK: - Status events
	
	private func finished() {
		// Kill any tasks
		if let task = task, task.isRunning {
			task.interrupt()
			task.terminate()
		}
		if let subtasks = subtasks {
			for sub in subtasks {
				if sub.isRunning {
					sub.interrupt()
					sub.terminate()
				}
			}
		}
		
		dataTask?.cancel()
		dataTask = nil
		downloadTask?.cancel()
		downloadTask = nil
		tmpFile = nil
		task = nil
		subtasks = nil
	}
	
	private func failed(reason: String) {
		finished()
		
		delegate?.downloadFailed?(self, reason: reason)
	}
	
	private func succeeded() {
		dataTask = nil
		downloadTask = nil
		
		task = nil
		subtasks = nil
		
		delegate?.downloadComplete?(self)
	}
	
	// MARK: - The unarchiver
	
	private func directoryForUnarchiving() -> URL? {
		if let downloadDirectory = downloadDirectory {
			return downloadDirectory
		}
		var directory = localDownloadDirectory.appendingPathComponent("unarchived-\(lastDownloadID)", isDirectory: true)
		// Pick a directory name that doesn't already exist

		while (try? directory.checkResourceIsReachable()) ?? false {
			lastDownloadID += 1
			directory = localDownloadDirectory.appendingPathComponent("unarchived-\(lastDownloadID)", isDirectory: true)
		}
		
		// Create the directory
		do {
			try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: nil)
			downloadDirectory = directory
			return directory
		} catch {
			return nil
		}
	}
	
	private func unarchiveFile(_ filename2: URL, to directory: URL) -> Process? {
		var filename = filename2
		// Some ifarchive mirrors give us .tar.Z.tar and .tar.gz.tar type files: replace those
		if filename.lastPathComponent.lowercased().hasSuffix(".tar.z.tar") {
			filename.deletePathExtension();filename.deletePathExtension();filename.deletePathExtension();
			filename.appendPathExtension("tar");filename.appendPathExtension("z");
		} else if filename.lastPathComponent.lowercased().hasSuffix(".tar.gz.tar") {
			filename.deletePathExtension();filename.deletePathExtension();filename.deletePathExtension();
			filename.appendPathExtension("tar");filename.appendPathExtension("gz");
		}
		
		// Creates an NSTask that will unarchive the specified filename (which must be supplied as stdin) to the specified directory
		let pathExtension = filename.pathExtension.lowercased()
		let withoutExtension = filename.deletingPathExtension()
		let result = Process()
		result.launchPath = "/usr/bin/env"
		
		switch pathExtension {
		case "zip":
			// Unarchive as a .zip file
			result.arguments = ["ditto", "-x", "-k", "-", directory.path]
			
		case "tar":
			// Is a something.tar file
			result.arguments = ["tar", "-xC", directory.path]

		case "z", "gz", "bz2":
			let nextStage = unarchiveFile(withoutExtension, to: directory)!
			
			// Pick the unarchiver to use
			let unarchiver: String
			switch pathExtension {
			case "gz":
				unarchiver = "gunzip"
				
			case "bz2":
				unarchiver = "bunzip2"
				
			case "z":
				unarchiver = "uncompress"
				
			default:
				unarchiver = "gunzip"
			}
			
			// Create the unarchiver
			result.arguments = [unarchiver]
			
			// Create the pipes to connect the next task to the unarchiver
			let pipe = Pipe()
			
			nextStage.standardInput = pipe
			result.standardOutput = pipe
			
			// Add the next stage to the list of subtasks
			if subtasks == nil {
				subtasks = []
			}
			subtasks!.append(nextStage)
			
			
		case "tgz":
			return unarchiveFile(withoutExtension.appendingPathExtension("tar").appendingPathExtension("gz"), to: directory)
			
		case "tbz", "tbz2":
			return unarchiveFile(withoutExtension.appendingPathExtension("tar").appendingPathExtension("bz2"), to: directory)

		default:
			// Default is just to copy the file
			var destFile = directory.appendingPathComponent(filename.lastPathComponent, isDirectory: false)
			if let suggestedFilename = suggestedFilename {
				destFile = directory.appendingPathComponent(suggestedFilename, isDirectory: false)
			}
			try! NSData().write(to: destFile, options: .atomic)
			result.arguments = ["cat", "-"]
			result.standardOutput = try! FileHandle(forWritingTo: destFile)
		}
		
		NotificationCenter.default.addObserver(self, selector: #selector(self.taskDidTerminate(_:)), name: Process.didTerminateNotification, object: result)

		return result
	}
	
	private func unarchiveFile() {
		guard directoryForUnarchiving() != nil else {
			failed(reason: "Couldn't create directory for unarchiving")
			return
		}
		
		task = unarchiveFile(tmpFile!, to: directoryForUnarchiving()!)
		guard task != nil else {
			// Oops: couldn't create the task
			failed(reason: "Could not decompress the downloaded file.")
			return
		}
		
		guard let tmpFile = tmpFile, (try? tmpFile.checkResourceIsReachable()) ?? false else {
			// Oops, the download file doesn't exist
			failed(reason: "The downloaded file was deleted before it could be unarchived.")
			return
		}
		
		// Set the input file handle for the main task
		do {
			task?.standardInput = try FileHandle(forReadingFrom: tmpFile)
		} catch {
			failed(reason: error.localizedDescription)
			return
		}
		NSLog("Unarchiving \(tmpFile) to \(downloadDirectory!)")
		
		// Notify the delegate that we're starting to unarchive the file
		delegate?.download?(self, completed: -1)
		delegate?.downloadUnarchiving?(self)

		// Start the tasks
		do {
			if let subtasks {
				for sub in subtasks {
					try sub.run()
				}
			}
			try task?.run()
		} catch {
			failed(reason: "Launch failure \(error)")
		}
	}

	// MARK: -
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse) async -> URLSession.ResponseDisposition {
		var status = 200
		if let response = response as? HTTPURLResponse {
			status = response.statusCode
		}
		
		if status >= 400 {
			// Failure: give up
			NSLog("Error: %li", status)
			
			switch status {
			case 403:
				failed(reason: "The server forbade access to the file")
				
			case 404:
				failed(reason: "The file was not found on the server")
				
			case 410:
				failed(reason: "The file is no longer available on the server")
				
			case 500:
				failed(reason: "The server is suffering from a fault")

			case 503:
				failed(reason: "The server is currently unavailable")
				
			default:
				failed(reason: "Server reported code \(status)")
			}
			
			return .cancel
		}
		
		// Create the download directory if it doesn't exist
		createDownloadDirectory()
		guard let downloadDirectory,
			  (try? downloadDirectory.checkResourceIsReachable()) ?? false else {
			failed(reason: "Couldn't create download directory")
			return .cancel
		}

		// Create the download file
		tmpFile = downloadDirectory.appendingPathComponent("download-\(lastDownloadID)")
		lastDownloadID += 1
		tmpFile = tmpFile!.appendingPathComponent(fullExtension(forFilename: response.suggestedFilename!)!)

		suggestedFilename = response.suggestedFilename
		
		if let suggestedFilename = suggestedFilename as NSString?, suggestedFilename.pathExtension == "txt" {
			// Some servers produce .zblorb.txt files, etc.
			if (suggestedFilename.deletingPathExtension as NSString).pathExtension.count > 0 {
				self.suggestedFilename = suggestedFilename.deletingPathExtension
			}
		}
		
		/*
		 
		 if (downloadFile) {
			 [downloadFile closeFile];
			 downloadFile = nil;
		 }
		 NSLog(@"Downloading to %@", tmpFile);
		 [[NSFileManager defaultManager] createFileAtPath: tmpFile
												 contents: [NSData data]
											   attributes: nil];
		 downloadFile = [NSFileHandle fileHandleForWritingAtPath: tmpFile];
		 
		 if (downloadFile == nil) {
			 // Failed to create the download file
			 NSLog(@"...Could not create file");
			 
			 [self failed: @"Unable to save the download to disk"];
			 completionHandler(NSURLSessionResponseCancel);
			 return;
		 }
		 
		 */
		
		delegate?.downloading?(self)
		
		return .becomeDownload
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		if let error {
			try? FileManager.default.removeItem(at: tmpFile!)
			tmpFile = nil
			
			NSLog("Download failed with error: \(error)")
			
			// Inform the delegate, and give up
			failed(reason: "Connection failed: \(error.localizedDescription)")
			
			return
		}
		
		// If we have an MD5, then verify that the file matches it
		if let md5 = expectedMD5 {
			var ckMD5 = Insecure.MD5()
			
			guard let readDownload = try? FileHandle(forReadingFrom: tmpFile!) else {
				failed(reason: "The downloaded file was deleted before it could be processed")
				return
			}
			
			// Read in the file and update the MD5 sum
			do {
				var readBytes = readDownload.readData(ofLength: 65536)
				while readBytes.count > 0 {
					ckMD5.update(data: readBytes)
					readBytes = readDownload.readData(ofLength: 65536)
				}
			}
			
			// Finish up and get the MD5 digest
			let bytes = ckMD5.finalize()

			NSLog("MD5 digest is \(bytes)")
			
			guard bytes == md5 else {
				NSLog("Could not verify download")
				failed(reason: "The downloaded file has an invalid checksum")
				return
			}
		}
		
		guard directoryForUnarchiving() != nil else {
			failed(reason: "Could not create a directory to decompress the downloaded file")
			return
		}
		
		// Unarchive the file if it's a zip or a tar file, or move it to the download directory
		unarchiveFile()
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
		self.downloadTask = downloadTask
		self.dataTask = nil
	}
	
	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		do {
			try FileManager.default.moveItem(at: location, to: tmpFile!)
		} catch {
			failed(reason: error.localizedDescription)
		}
	}

	public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten downloadedSoFar: Int64, totalBytesExpectedToWrite expectedLength: Int64) {
		if expectedLength != 0 {
			let proportion = Double(downloadedSoFar)/Double(expectedLength)
			
			delegate?.download?(self, completed: Float(proportion))
		}
	}
	
	// MARK: - NSTask delegate
	
	@objc private func taskDidTerminate(_ noti: Notification) {
		// Do nothing if no task is running
		guard let task else {
			return
		}
		// Check if all of the tasks have finished
		var finished = true
		var succeeded = true
		
		if let subtasks {
			for sub in subtasks {
				if sub.isRunning {
					finished = false
				} else if sub.terminationStatus != 0 {
					succeeded = false
				}
			}
		}
		
		if task.isRunning {
			finished = false
		} else if task.terminationStatus != 0 {
			succeeded = false
		}
		
		if !succeeded {
			// Oops, failed
			NSLog("Failed to unarchive \(tmpFile!)")
			failed(reason: "The downloaded file failed to decompress")
			return
		} else if finished {
			// Download has successfully completed
			NSLog("Unarchiving task succeeded")
			self.succeeded()
		}
	}
}
