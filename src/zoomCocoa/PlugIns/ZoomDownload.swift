//
//  ZoomDownload.swift
//  ZoomPlugIns
//
//  Created by C.W. Betts on 11/3/21.
//

import Foundation
import XADMaster.Unarchiver
import CommonCrypto.CommonDigest

private var downloadDirectoryURL: URL = {
	let tmp = NSTemporaryDirectory()
	var tmpURL = URL(fileURLWithPath: tmp)
	tmpURL.appendPathComponent("Zoom-Downloads-\(getpid())")
	
	return tmpURL
}()
private var lastDownloadId = 0

@objcMembers public class ZoomDownload2: NSObject, URLSessionDataDelegate, URLSessionDelegate, XADSimpleUnarchiverDelegate {
	/// The download delegate
	public weak var delegate: ZoomDownload2Delegate?
	
	/// The url for this download
	public let url: URL
	
	private var session: URLSession!
	/// The connection that the download will be loaded via
	private var dataTask: URLSessionDataTask?

	/// Removes the temporary directory used for downloads (ie, when terminating)
	class func removeTemporaryDirectory() {
		guard (try? downloadDirectoryURL.checkResourceIsReachable()) ?? false else {
			return
		}
		
		try? FileManager.default.removeItem(at: downloadDirectoryURL)
	}
	
	/// A file handle containing the file that we're downloading
	private var downloadFile: FileHandle?
	/// The file that the download is going to
	private var tmpFile: URL?
	/// The expected length of the download
	private var expectedLength: Int64 = 0
	/// The amount downloaded so far
	private var downloadedSoFar: Int64 = 0
	
	private var unarchiver: XADSimpleUnarchiver?
	
	/// Prepares to download the specified URL
	@objc(initWithURL:)
	public init(with url: URL) {
		self.url = url
		
		super.init()
		
		let config = URLSessionConfiguration.ephemeral
		config.networkServiceType = .background
		session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
	}
	
	/// The expected MD5 for the downloaded file
	public var expectedMD5: Data?
	
	deinit {
		
		if let tmpFile = tmpFile,
		   (try? tmpFile.checkResourceIsReachable()) ?? false {
			NSLog("Removing: %@", tmpFile as NSURL)
			try? FileManager.default.removeItem(at: tmpFile)
		}
		
		// Delete the temporary directory
		if let tmpDirectory = downloadDirectory,
		   (try? tmpDirectory.checkResourceIsReachable()) ?? false,
		   let isDirRes = try? tmpDirectory.resourceValues(forKeys: [.isDirectoryKey]),
		   let isDir = isDirRes.isDirectory,
		   isDir {
			NSLog("Removing: %@", tmpDirectory as NSURL)
			try? FileManager.default.removeItem(at: tmpDirectory)
		}
		
		// Kill any tasks

	}
	
	// MARK: - Starting the download
	
	public func startDownload() {
		// Do nothing if this download is already running
		guard dataTask == nil else {
			return
		}

		// Let the delegate know
		delegate?.downloadStarting?(self)
		
		NSLog("Downloading: %@", (url as NSURL))
		
		// Create a connection to download the specified URL
		let request = URLRequest(url: url, cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30)
		dataTask = session.dataTask(with: request)
		dataTask!.taskDescription = "Zoom: Downloading \(url.lastPathComponent)"
	}

	private func createDownloadDirectory() {
		
	}
	/*
	 - (void) createDownloadDirectory {
		 if (!downloadDirectory) return;
		 
		 BOOL exists;
		 BOOL isDir;
		 
		 exists = [[NSFileManager defaultManager] fileExistsAtPath: downloadDirectory
													   isDirectory: &isDir];
		 if (!exists) {
			 [[NSFileManager defaultManager] createDirectoryAtPath: downloadDirectory
														withIntermediateDirectories: NO
														attributes: nil
															 error:NULL];
		 } else if (!isDir) {
			 downloadDirectory = [downloadDirectory stringByAppendingString: @"-1"];
			 [self createDownloadDirectory];
		 }
	 }
*/
	 // MARK: - Status events

	private func finished() {
		dataTask?.cancel()
		dataTask = nil
		tmpFile = nil;
		downloadFile = nil;
//		task = nil;
//		subtasks = nil;
	}

	private func failed(_ reason: String, error: Error? = nil) {
		self.finished()
		
		delegate?.downloadFailed?(self, reason: reason, error: error)
	}

	private func succeeded() {
		dataTask = nil
		
		// Let the download delegate know that the download has finished
		delegate?.downloadComplete?(self)
	}
	
	// MARK: - The unarchiver
	private func directoryForUnarchiving() -> URL? {
		if let tmpDirectory = downloadDirectory {
			return tmpDirectory
		}
		return nil
	}
	/*

	 - (NSString*) directoryForUnarchiving {
		 if (tmpDirectory != nil) return tmpDirectory;
		 if (!downloadDirectory) return nil;
		 
		 NSString* directory = [downloadDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"unarchived-%i", lastDownloadId]];
		 
		 // Pick a directory name that doesn't already exist
		 while ([[NSFileManager defaultManager] fileExistsAtPath: directory]) {
			 lastDownloadId++;
			 directory = [downloadDirectory stringByAppendingPathComponent: [NSString stringWithFormat: @"unarchived-%i", lastDownloadId]];
		 }
		 
		 // Create the directory
		 if ([[NSFileManager defaultManager] createDirectoryAtPath: directory
									   withIntermediateDirectories: NO
														attributes: nil
															 error: NULL]) {
			 return tmpDirectory = [directory copy];
		 } else {
			 return nil;
		 }
	 }

	 - (NSTask*) unarchiveFile: (NSString*) filename
				   toDirectory: (NSString*) directory {
		 // Some ifarchive mirrors give us .tar.Z.tar and .tar.gz.tar type files: replace those
		 if ([[filename lowercaseString] hasSuffix: @".tar.z.tar"]) {
			 filename = [filename substringToIndex: [filename length] - [@".tar.z.tar" length]];
			 filename = [filename stringByAppendingString: @".tar.z"];
		 }
		 if ([[filename lowercaseString] hasSuffix: @".tar.gz.tar"]) {
			 filename = [filename substringToIndex: [filename length] - [@".tar.gz.tar" length]];
			 filename = [filename stringByAppendingString: @".tar.gz"];
		 }
		 
		 // Creates an NSTask that will unarchive the specified filename (which must be supplied as stdin) to the specified directory
		 NSString* pathExtension = [[filename pathExtension] lowercaseString];
		 NSString* withoutExtension = [filename stringByDeletingPathExtension];
		 BOOL needNextStage = NO;
		 NSTask* result = [[NSTask alloc] init];
		 
		 [result setLaunchPath: @"/usr/bin/env"];
		 
		 if ([pathExtension isEqualToString: @"zip"]) {
			 // Unarchive as a .zip file
			 [result setArguments: @[@"ditto",
									 @"-x",
									 @"-k",
									 @"-",
									 directory]];
		 } else if ([pathExtension isEqualToString: @"tar"]) {
			 // Is a something.tar file
			 [result setArguments: @[@"tar",
									 @"-xC",
									 directory]];
		 } else if ([pathExtension isEqualToString: @"gz"]
					|| [pathExtension isEqualToString: @"bz2"]
					|| [pathExtension isEqualToString: @"z"]) {
			 // Is a something.gz file: need to do a two-stage task
			 NSTask* nextStage = [self unarchiveFile: withoutExtension
										 toDirectory: directory];
			 
			 // Pick the unarchiver to use
			 NSString* unarchiver = @"gunzip";
			 if ([pathExtension isEqualToString: @"gz"])		unarchiver = @"gunzip";
			 if ([pathExtension isEqualToString: @"bz2"])	unarchiver = @"bunzip2";
			 if ([pathExtension isEqualToString: @"z"])		unarchiver = @"uncompress";
			 
			 // Create the unarchiver
			 [result setArguments: @[unarchiver]];
			 
			 // Create the pipes to connect the next task to the unarchiver
			 NSPipe* pipe = [NSPipe pipe];
			 
			 [nextStage setStandardInput: pipe];
			 [result setStandardOutput: pipe];
			 
			 // Add the next stage to the list of subtasks
			 if (subtasks == nil) subtasks = [[NSMutableArray alloc] init];
			 [subtasks addObject: nextStage];
		 } else if ([pathExtension isEqualToString: @"tgz"]) {
			 return [self unarchiveFile: [[withoutExtension stringByAppendingPathExtension: @"tar"] stringByAppendingPathExtension: @"gz"]
							toDirectory: directory];
		 } else if ([pathExtension isEqualToString: @"tbz"] || [pathExtension isEqualToString: @"tbz2"]) {
			 return [self unarchiveFile: [[withoutExtension stringByAppendingPathExtension: @"tar"] stringByAppendingPathExtension: @"bz2"]
							toDirectory: directory];
		 } else {
			 // Default is just to copy the file
			 NSString* destFile = [directory stringByAppendingPathComponent: [filename lastPathComponent]];
			 if (suggestedFilename && [[suggestedFilename lastPathComponent] length] > 0) destFile = [directory stringByAppendingPathComponent: [suggestedFilename lastPathComponent]];
			 [[NSFileManager defaultManager] createFileAtPath: destFile
													 contents: [NSData data]
												   attributes: nil];

			 [result setArguments: @[@"cat", @"-"]];
			 [result setStandardOutput: [NSFileHandle fileHandleForWritingAtPath: destFile]];
		 }
		 
		 [[NSNotificationCenter defaultCenter] addObserver: self
												  selector: @selector(taskDidTerminate:)
													  name: NSTaskDidTerminateNotification
													object: result];
		 return result;
	 }

	 */
	
	func unarchiveFile() {
		guard directoryForUnarchiving() != nil else {
			failed("Couldn't create directory for unarchiving")
			return
		}
		unarchiver = nil
		do {
			unarchiver = try XADSimpleUnarchiver(forPath: tmpFile!.path)
			unarchiver!.destination = directoryForUnarchiving()!.path
			unarchiver!.delegate = self
			try unarchiver!.parse()
			
			//TODO: spin off to a seperate thread
		} catch {
			// Oops: couldn't create the task
			failed("Could not decompress the downloaded file.", error: error)
			return
		}
		
		// Notify the delegate that we're starting to unarchive the
		delegate?.download?(self, completed: -1)
		try? unarchiver?.unarchive()
		delegate?.downloadUnarchiving?(self)
	}
	
	// MARK: - NSURLConnection delegate

	private func fullExtensionFor(_ filename: String) -> String? {
		let ext = (filename as NSString).pathExtension
		let withoutExt = (filename as NSString).deletingPathExtension
		
		if ext.count <= 0 {
			return nil
		}
		
		if let extraExtension = fullExtensionFor(withoutExt) {
			return (extraExtension as NSString).appendingPathExtension(ext)
		} else {
			return ext
		}
	}
	
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		var status = 200
		if let hResponse = response as? HTTPURLResponse {
			status = hResponse.statusCode
		}
		
		if status >= 400 {
			// Failure: give up
			NSLog("Error: %li", status);

			switch status {
			case 403:
				failed("The server forbade access to the file")
				
			case 404:
				failed("The file was not found on the server")
				
			case 410:
				failed("The file is no longer available on the server")
				
			case 500:
				failed("The server is suffering from a fault")
				
			case 503:
				failed("The server is currently unavailable")
				
			default:
				failed("Server reported code \(status)")
			}
			
			completionHandler(.cancel)
			return
		}
		
		expectedLength = response.expectedContentLength
		downloadedSoFar = 0
		
		// Create the download directory if it doesn't exist
		createDownloadDirectory()
		
		tmpFile = downloadDirectory?.appendingPathComponent("download-\(lastDownloadId)")
		lastDownloadId += 1
		tmpFile?.appendPathExtension(fullExtensionFor(response.suggestedFilename ?? "tmp.zip")!)
		
		suggestedFilename = response.suggestedFilename ?? "tmp.zip"
		if (suggestedFilename! as NSString).pathExtension.caseInsensitiveCompare("txt") == .orderedSame {
			// Some servers produce .zblorb.txt files, etc.
			if ((suggestedFilename! as NSString).deletingPathExtension as NSString).pathExtension.count > 0 {
				suggestedFilename = (suggestedFilename! as NSString).deletingPathExtension
			}
		}
		
		if downloadFile != nil {
			downloadFile!.closeFile()
			downloadFile = nil
		}
		
		NSLog("Downloading to %@", (tmpFile! as NSURL))
		try? Data().write(to: tmpFile!)
		do {
			downloadFile = try FileHandle(forWritingTo: tmpFile!)
		} catch {
			// Failed to create the download file
			NSLog("...Could not create file")
			
			failed("Unable to save the download to disk", error: error)
			completionHandler(.cancel)
			return
		}
		
		delegate?.downloading?(self)
		completionHandler(.allow)
	}
		
	public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		// Write to the download file
		if let downloadFile = downloadFile {
			if #available(macOS 10.15.4, *) {
				try? downloadFile.write(contentsOf: data)
			} else {
				downloadFile.write(data)
			}
			
			// Let the delegate know of the progress
			downloadedSoFar += Int64(data.count)
			
			if expectedLength != 0 {
				let percent = Double(downloadedSoFar) / Double(expectedLength)
				
				delegate?.download?(self, completed: Float(percent))
			}
		}
	}
	
	public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		if let error = error {
			// Delete the downloaded file
			if let downloadFile = downloadFile {
				downloadFile.closeFile()
				self.downloadFile = nil;

				try? FileManager.default.removeItem(at: tmpFile!)
			}

			tmpFile = nil;

			NSLog("Download failed with error: %@", (error as NSError))

			// Inform the delegate, and give up
			failed("Connection failed: \(error.localizedDescription)", error: error)
			return
		}
		
		if let downloadFile = downloadFile {
			// Finish writing the file
			downloadFile.closeFile()
			self.downloadFile = nil
			
			// If we have an MD5, then verify that the file matches it
			if let md5 = expectedMD5 {
				var state = CC_MD5_CTX()
				CC_MD5_Init(&state);
				
				let readDownload: FileHandle
				do {
					readDownload = try FileHandle(forReadingFrom: tmpFile!)
				} catch {
					failed("The downloaded file was deleted before it could be processed", error: error)
					return
				}
				
				// Read in the file and update the MD5 sum
				autoreleasepool {
					var readBytes = readDownload.readData(ofLength: 65536)
					while readBytes.count > 0 {
						readBytes.withUnsafeBytes { bufPtr in
							_=CC_MD5_Update(&state, bufPtr.baseAddress, CC_LONG(bufPtr.count))
						}
						readBytes = readDownload.readData(ofLength: 65536)
					}
				}
				
				var digest: [UInt8] = Array(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
				CC_MD5_Final(&digest, &state)
				let digestData = Data(digest)
				NSLog("MD5 digest is %@", digestData as NSData)
				if digestData != md5 {
					NSLog("Could not verify download")
					failed("The downloaded file has an invalid checksum")
					return
				}
			}
			
			// Create the download directory
			guard directoryForUnarchiving() != nil else {
				// Couldn't create the directory
				failed("Could not create a directory to decompress the downloaded file")
				return
			}
			
			// Unarchive the file if it's a zip or a tar file, or move it to the download directory
			unarchiveFile()
		}
	}

	/*

	 #pragma mark - NSTask delegate

	 - (void) taskDidTerminate: (NSNotification*) not {
		 // Do nothing if no task is running
		 if (task == nil) return;
		 
		 // Check if all of the tasks have finished
		 BOOL finished = YES;
		 BOOL succeeded = YES;
		 
		 if (subtasks) {
			 for (NSTask* sub in subtasks) {
				 if ([sub isRunning]) {
					 finished = NO;
				 } else if ([sub terminationStatus] != 0) {
					 succeeded = NO;
				 }
			 }
		 }
		 if ([task isRunning]) {
			 finished = NO;
		 } else if ([task terminationStatus] != 0) {
			 succeeded = NO;
		 }
		 
		 if (!succeeded) {
			 // Oops, failed
			 NSLog(@"Failed to unarchive %@", tmpFile);
			 [self failed: @"The downloaded file failed to decompress"];
			 return;
		 } else if (finished) {
			 // Download has successfully completed
			 NSLog(@"Unarchiving task succeeded");
			 [self succeeded];
		 }
	 }

	 */
	
	/// The directoruy that the download was unarchived to
	public private(set) var downloadDirectory: URL?
	/// The filename suggested for this download in the response
	public private(set) var suggestedFilename: String?
}

/// Delegate methods for the download class
@objc public protocol ZoomDownload2Delegate : NSObjectProtocol {
	/// A download is starting
	@objc optional func downloadStarting(_ download: ZoomDownload2)

	/// The download has completed
	@objc optional func downloadComplete(_ download: ZoomDownload2)

	/// The download failed for some reason
	@objc optional func downloadFailed(_ download: ZoomDownload2, reason: String, error: Error?)

	
	/// The download is connecting
	@objc optional func downloadConnecting(_ download: ZoomDownload2)

	/// The download is reading data
	@objc optional func downloading(_ download: ZoomDownload2)

	/// Value between 0 and 1 indicating how far the download has progressed
	@objc optional func download(_ download: ZoomDownload2, completed complete: Float)

	/// Indicates that a .zip or .tar file is being decompressed
	@objc optional func downloadUnarchiving(_ download: ZoomDownload2)
}
