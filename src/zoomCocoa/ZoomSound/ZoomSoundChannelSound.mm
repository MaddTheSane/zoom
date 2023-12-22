//
//  ZoomSoundChannelSound.m
//  ZoomView
//
//  Created by C.W. Betts on 4/10/22.
//

#import "ZoomSoundChannelSound.h"
#import <ZoomView/ZoomProtocol.h>
#import "ZoomSound.h"

#include <SFBAudioEngine/AudioPlayer.h>
#include <SFBAudioEngine/AudioDecoder.h>
#include <SFBAudioEngine/LoopableRegionDecoder.h>
#include <SFBAudioEngine/CoreAudioOutput.h>

#pragma GCC visibility push(hidden)

class ZFileInputSource final: public SFB::InputSource {
public:
	ZFileInputSource(id<ZFile> bytes): SFB::InputSource(), _file(bytes) { }
	virtual ~ZFileInputSource() = default;

private:
	virtual bool _Open(CFErrorRef *error) {
#pragma unused(error)
		return true;
	}
	virtual bool _Close(CFErrorRef *error) {
#pragma unused(error)
		[_file seekTo:0];
		return true;
	}
	virtual SInt64 _Read(void *buffer, SInt64 byteCount);
	virtual bool _AtEOF() const {
		return _file.endOfFile;
	}
	virtual SInt64 _GetOffset() const {
		return [_file seekPosition];
	}
	virtual SInt64 _GetLength() const {
		return _file.fileSize;
	}

	// Optional seeking support
	inline virtual bool _SupportsSeeking() const {
		return true;
	}
	
	virtual bool _SeekToOffset(SInt64 offset) {
		[_file seekTo: offset];
		return true;
	}
	
	// Data members
	id<ZFile> _file;
};

#pragma GCC visibility pop

static SFB::InputSource::unique_ptr CreateWithZFile(id<ZFile> zFile, CFErrorRef *error = nullptr)
{
#pragma unused(error)

	if (nullptr == zFile || 0 >= [zFile fileSize]) {
		return nullptr;
	}

	return SFB::InputSource::unique_ptr(new ZFileInputSource(zFile));
}

@implementation ZoomSoundChannelSound {
	SFB::Audio::Player    *_player;        // The player instance
	
	NSString *mimeString;
}

@end

SInt64 ZFileInputSource::_Read(void *buffer, SInt64 byteCount) {
	if (_file.seekPosition + byteCount > _file.fileSize) {
		byteCount = _file.fileSize - _file.seekPosition;
	}
	NSData * dataOut = [_file readBlock: byteCount];
	[dataOut getBytes:buffer length:byteCount];
	return byteCount;
}
