//
//  ZoomUnarchiveOperation.swift
//  ZoomPlugIns
//
//  Created by C.W. Betts on 12/24/21.
//

import Cocoa
import XADMaster.ArchiveParser

class ZoomUnarchiveOperation: Operation, XADArchiveParserDelegate, ProgressReporting {
	private let archiveLocation: URL
	private let destinationLocation: URL
	
	private var parser: XADArchiveParser?
	private var entries = [[XADArchiveKeys : Any]]()
	
	var progress: Progress = Progress.discreteProgress(totalUnitCount: 100)
	
	init(archive: URL, destination: URL) {
		archiveLocation = archive
		destinationLocation = destination
		super.init()
		progress.kind = .file
		progress.fileOperationKind = .decompressingAfterDownloading
		progress.fileURL = destination
		progress.cancellationHandler = {
			self.cancel()
		}
	}
	
	override func main() {
		let parser: XADArchiveParser
		do {
			parser = try XADArchiveParser.archiveParser(for: archiveLocation)
			parser.delegate = self
		} catch {
			NSLog("Unable to open archive at \(archiveLocation.path): \(error.localizedDescription)")
			progress.cancel()
			cancel()
			return
		}
		self.parser = parser
		defer {
			self.parser = nil
		}
		
		do {
			try parser.parse()
		} catch {
			NSLog("Unable to parse archive at \(archiveLocation.path): \(error.localizedDescription)")
			progress.cancel()
			cancel()
			return
		}
		
		progress.fileTotalCount = entries.count
		progress.fileCompletedCount = 0
		
		// Now that we have all the needed entries, iterate the entries.
		for entry in entries {
			guard !isCancelled else {
				return
			}
			guard let handle = try? parser.handleForEntry(with: entry, wantChecksum: false) else {
				cancel()
				return
			}
			
			let fileData = handle.fileContents()
			
			// After it is done...
			progress.fileCompletedCount! += 1
		}
	}
	
	private func predictTotalSize() -> Int {
		var total = 0
		for dict in entries {
			guard let num = dict[.fileSizeKey] as? Int64 else {
				continue
			}
			total += Int(num)
		}
		return total
	}
	
	private func extract(entry dict: [XADArchiveKeys: Any]) throws {
		let isDir = (dict[.isDirectoryKey] as? Bool) ?? false
		let isLink = (dict[.isLinkKey] as? Bool) ?? false
		let isRes = (dict[.isResourceForkKey] as? Bool) ?? false
		
		var path = destinationLocation
		do {
			let name = dict[.fileNameKey] as! XADPath
			let pathComps = name.canonicalPathComponents
			for component in pathComps {
				if component == "/" {
					continue
				}
				// Replace ".." components with "__Parent__". ".." components in the middle
				// of the path have already been collapsed by canonicalPathComponents.
				if component == ".." {
					path.appendPathComponent("__Parent__")
				} else {
					let sanitized = XADPlatform.sanitizedPathComponent(component)
					path.appendPathComponent(sanitized)
				}
			}
		}
		
		
	}
	
	/*
	 -(BOOL)extractEntryWithDictionary:(NSDictionary<XADArchiveKeys,id> *)dict as:(nullable NSString *)path forceDirectories:(BOOL)force error:(NSError**)outErr
	 {
		 @autoreleasepool {

		 NSNumber *dirnum=dict[XADIsDirectoryKey];
		 NSNumber *linknum=dict[XADIsLinkKey];
		 NSNumber *resnum=dict[XADIsResourceForkKey];
		 NSNumber *archivenum=dict[XADIsArchiveKey];
		 BOOL isdir=dirnum&&dirnum.boolValue;
		 BOOL islink=linknum&&linknum.boolValue;
		 BOOL isres=resnum&&resnum.boolValue;
		 BOOL isarchive=archivenum&&archivenum.boolValue;

		 // If we were not given a path, pick one ourselves.
		 if(!path)
		 {
			 XADPath *name=dict[XADFileNameKey];
			 NSString *namestring=name.sanitizedPathString;

			 if(destination) path=[destination stringByAppendingPathComponent:namestring];
			 else path=namestring;

			 // Adjust path for resource forks.
			 path=[self adjustPathString:path forEntryWithDictionary:dict];
		 }

		 // Ask for permission and possibly a path, and report that we are starting.
		 if(delegate)
		 {
			 if(![delegate unarchiver:self shouldExtractEntryWithDictionary:dict suggestedPath:&path])
			 {
				 return YES;
			 }
			 if ([delegate respondsToSelector:@selector(unarchiver:willExtractEntryWithDictionary:to:)]) {
				 [delegate unarchiver:self willExtractEntryWithDictionary:dict to:path];
			 }
		 }

		 XADError error=0;
		 NSError *tmpErr = nil;
		 
		 BOOL okay=[self _ensureDirectoryExists:path.stringByDeletingLastPathComponent error:&tmpErr];
		 if(!okay) goto end;

		 // Attempt to extract embedded archives if requested.
		 if(isarchive&&delegate)
		 {
			 NSString *unarchiverpath=path.stringByDeletingLastPathComponent;

			 if([delegate unarchiver:self shouldExtractArchiveEntryWithDictionary:dict to:unarchiverpath])
			 {
				 okay=[self _extractArchiveEntryWithDictionary:dict to:unarchiverpath name:path.lastPathComponent error:&tmpErr];
				 // If extraction was attempted, and succeeded for failed, skip everything else.
				 // Otherwise, if the archive couldn't be opened, fall through and extract normally.
				 if(!okay && ([tmpErr.domain isEqualToString:XADErrorDomain] && tmpErr.code != XADErrorSubArchive)) goto end;
			 }
		 }

		 // Extract normally.
		 if(isres)
		 {
			 switch(forkstyle)
			 {
				 case XADForkStyleIgnored:
				 break;

				 case XADForkStyleMacOSX:
					 if(!isdir) {
						 error=[XADPlatform extractResourceForkEntryWithDictionary:dict unarchiver:self toPath:path];
						 if (error == XADErrorNone) {
							 okay = YES;
							 tmpErr = nil;
						 } else {
							 okay = NO;
							 tmpErr = [NSError errorWithDomain:XADErrorDomain code:error userInfo:nil];
						 }
					 }
				 break;

				 case XADForkStyleHiddenAppleDouble:
				 case XADForkStyleVisibleAppleDouble:
				 {
					 error=[self _extractResourceForkEntryWithDictionary:dict asAppleDoubleFile:path];
					 if (error == XADErrorNone) {
						 okay = YES;
						 tmpErr = nil;
					 } else {
						 okay = NO;
						 tmpErr = [NSError errorWithDomain:XADErrorDomain code:error userInfo:nil];
					 }
				 }
				 break;

				 case XADForkStyleHFVExplorerAppleDouble:
					 // We need to make sure there is an empty file for the data fork in all
					 // cases, so just try to recover the original filename and create an empty
					 // file there in case one doesn't exist, and this isn't a directory.
					 // Kludge in the same file attributes as the resource fork. If there is
					 // an actual data fork later, it will overwrite this file. There special-case
					 // code to avoid collision warnings.
					 if(![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:NULL] && !isdir)
					 {
						 NSString *dirpart=path.stringByDeletingLastPathComponent;
						 NSString *namepart=path.lastPathComponent;
						 if([namepart hasPrefix:@"%"])
						 {
							 NSString *originalname=[namepart substringFromIndex:1];
							 NSString *datapath=[dirpart stringByAppendingPathComponent:originalname];
							 [[NSData data] writeToFile:datapath atomically:NO];
							 [self _updateFileAttributesAtPath:datapath forEntryWithDictionary:dict deferDirectories:!force];
						 }
					 }
					 error=[self _extractResourceForkEntryWithDictionary:dict asAppleDoubleFile:path];
					 if (error == XADErrorNone) {
						 okay = YES;
						 tmpErr = nil;
					 } else {
						 okay = NO;
						 tmpErr = [NSError errorWithDomain:XADErrorDomain code:error userInfo:nil];
					 }
				 break;

				 default:
					 // TODO: better error
					 error=XADErrorBadParameters;
					 okay = NO;
					 tmpErr = [NSError errorWithDomain:XADErrorDomain code:XADErrorBadParameters userInfo:nil];

				 break;
			 }
		 }
		 else if(isdir)
		 {
			 error=[self _extractDirectoryEntryWithDictionary:dict as:path];
		 }
		 else if(islink)
		 {
			 error=[self _extractLinkEntryWithDictionary:dict as:path];
		 }
		 else
		 {
			 error=[self _extractFileEntryWithDictionary:dict as:path];
		 }

		 if(!error)
		 {
			 error=[self _updateFileAttributesAtPath:path forEntryWithDictionary:dict deferDirectories:!force];
		 }

		 if (error == XADErrorNone) {
			 okay = YES;
			 tmpErr = nil;
		 } else {
			 okay = NO;
			 tmpErr = [NSError errorWithDomain:XADErrorDomain code:error userInfo:nil];
		 }

		 // Report success or failure
		 end:
		 if(delegate && [delegate respondsToSelector:@selector(unarchiver:didExtractEntryWithDictionary:to:error:)])
		 {
			 [delegate unarchiver:self didExtractEntryWithDictionary:dict to:path nserror:okay ? nil : tmpErr];
		 }
		 if (outErr && tmpErr) {
			 *outErr = tmpErr;
		 }

		 return okay;
		 }
	 }
	 */
	
	// MARK: - XADArchiveParserDelegate calls
	
	func archiveParserNeedsPassword(_ parser: XADArchiveParser) {
		//Just fail...
		cancel()
	}
	
	func archiveParsingShouldStop(_ parser: XADArchiveParser) -> Bool {
		return isCancelled
	}
	
	func archiveParser(_ parser: XADArchiveParser, foundEntryWith dict: [XADArchiveKeys : Any]) {
		assert(parser === self.parser)
		entries.append(dict)
	}
}
