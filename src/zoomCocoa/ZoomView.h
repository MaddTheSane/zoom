//
//  ZoomView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import <ZoomView/ZoomProtocol.h>
#import <ZoomView/ZoomMoreView.h>
#import <ZoomView/ZoomTextView.h>
#import <ZoomView/ZoomScrollView.h>
#import <ZoomView/ZoomPreferences.h>
#import <ZoomView/ZoomCursor.h>
#import <ZoomView/ZoomInputLine.h>
#import <ZoomView/ZoomBlorbFile.h>
#import <ZoomView/ZoomTextToSpeech.h>
#import <ZoomView/ZoomViewProtocols.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(unsigned int, ZFontStyle) {
	ZFontStyleNone = 0,
	ZFontStyleBold = 1,
	ZFontStyleUnderline = 2,
	ZFontStyleFixed = 4,
	ZFontStyleSymbolic = 8
};

extern NSAttributedStringKey const ZoomStyleAttributeName NS_SWIFT_NAME(zoomStyle);
@protocol ZoomViewDelegate;

@class ZoomScrollView;
@class ZoomTextView;
@class ZoomPixmapWindow;
@class ZoomLowerWindow;
@class ZoomUpperWindow;
@interface ZoomView : NSView <ZDisplay, NSSecureCoding, NSTextStorageDelegate, NSTextViewDelegate, NSOpenSavePanelDelegate, ZoomCursorDelegate, ZoomInputLineDelegate>

- (instancetype)initWithFrame:(NSRect)frame NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)decoder;

//! The delegate
@property (weak) id<ZoomViewDelegate> delegate;

- (void) killTask;

//! debugTask forces a breakpoint at the next instruction. Note that the task must have
//! debugging symbols loaded, or this will kill the task. Also note that the effect may
//! be different than expected if the task is waiting for input.
- (void) debugTask;

@property (nonatomic) CGFloat scaleFactor;

// Specifying what to run
- (void) runNewServer: (nullable NSString*) serverName;
@property (nullable, nonatomic, strong) id<ZMachine> zMachine;

// Scrolling, more prompt
- (void) scrollToEnd;
- (void) resetMorePrompt;
- (void) updateMorePrompt;

- (void) setShowsMorePrompt: (BOOL) shown;
- (void) displayMoreIfNecessary;
- (void) page;

- (void) retileUpperWindowIfRequired;

// Formatting a string
/// Strings come from Zoom's server formatted with `ZStyle`s rather than
/// actual styles (so that the interface can choose it's own formatting).
/// So we need this to translate those styles into 'real' ones.
- (NSDictionary<NSAttributedStringKey,id>*) attributesForStyle: (ZStyle*) style;
/// Strings come from Zoom's server formatted with `ZStyle`s rather than
/// actual styles (so that the interface can choose its own formatting).
/// So we need this to translate those styles into 'real' ones.
- (NSAttributedString*) formatZString: (NSString*) zString
                            withStyle: (ZStyle*) style;

@property (readonly, strong) ZoomTextView *textView;
- (void) writeAttributedString: (NSAttributedString*) string;
- (void) clearLowerWindowWithStyle: (ZStyle*) style;

/// View with input focus
@property (weak) id<ZWindow> focusedView;

// Dealing with the history
- (nullable NSString*) lastHistoryItem;
- (nullable NSString*) nextHistoryItem;

// Fonts, colours, etc
/// @deprecated Use `-fontFromStyle:` instead.
- (null_unspecified NSFont*) fontWithStyle: (ZFontStyle) style NS_DEPRECATED_WITH_REPLACEMENT_MAC("-fontFromStyle:", 10.2, 10.15);
- (nullable NSFont*) fontFromStyle: (ZFontStyle) style;
- (NSColor*) foregroundColourForStyle: (ZStyle*) style;
- (NSColor*) backgroundColourForStyle: (ZStyle*) style;

- (void) setFonts:   (NSArray<NSFont*>*) fonts;
- (void) setColours: (NSArray<NSColor*>*) colours;

// File saving
@property OSType creatorCode;

// The upper window
@property (nonatomic, readonly) int upperWindowSize;
@property (nonatomic) CGFloat upperBufferHeight;
- (void) rearrangeUpperWindows;
@property (nonatomic, readonly, copy) NSArray<ZoomUpperWindow*> *upperWindows;
- (void) padToLowerWindow;

- (void) upperWindowNeedsRedrawing;

// Event handling
- (BOOL) handleKeyDown: (NSEvent*) theEvent;
- (void) clickAtPointInWindow: (NSPoint) windowPos
					withCount: (NSInteger) count;

// Setting/updating preferences
- (void) setPreferences: (ZoomPreferences*) prefs;
@property (nullable, nonatomic, strong) ZoomPreferences *preferences;
- (void) preferencesHaveChanged: (NSNotification*)noti;

- (void) reformatWindow;

// Autosaving
- (BOOL) createAutosaveDataWithCoder: (NSCoder*) encoder;
- (void) restoreAutosaveFromCoder: (NSCoder*) decoder;

@property (nonatomic, readonly, getter=isRunning) BOOL running;

- (void) restoreSaveState: (NSData*) state;

// 'Manual' input
@property NSPoint inputLinePos;
@property (nonatomic, strong) ZoomInputLine *inputLine;

// Output receivers
- (void) addOutputReceiver: (id<ZoomViewOutputReceiver>) receiver;
- (void) removeOutputReceiver: (id<ZoomViewOutputReceiver>) receiver;

- (void) orInputCommand: (NSString*) command;
- (void) orInputCharacter: (NSString*) character;
- (void) orOutputText:   (NSString*) outputText;
- (void) orWaitingForInput;
- (void) orInterpreterRestart;

@property (nonatomic, null_resettable, readonly, strong) ZoomTextToSpeech *textToSpeech;

// Input sources (nil = default, window input source)
@property (nonatomic, strong, nullable) id<ZoomViewInputSource> inputSource;
- (void) removeInputSource: (id<ZoomViewInputSource>) source;

//! Resources
@property (nullable, strong) ZoomBlorbFile *resources;

//! Terminating characters
@property (nullable, copy) NSSet<NSNumber*> *terminatingCharacters;

- (oneway void) setTerminatingCharacters: (in nullable bycopy NSSet<NSNumber*>*) characters;


- (void) endOfLineReached: (ZoomInputLine*) sender;
@end

//! ZoomView delegate methods
@protocol ZoomViewDelegate <NSObject>
@optional

- (void) zMachineStarted: (nullable id) sender;
- (void) zMachineFinished: (nullable id) sender;

@property (nullable, nonatomic, readonly, copy) NSString *defaultSaveDirectory;
- (BOOL)      useSavePackage;
- (void)      prepareSavePackage: (ZPackageFile*) file;
- (BOOL)	  loadedSkeinData: (NSData*) skeinData error:(NSError**)error;

- (void) hitBreakpoint: (int) pc;

- (void) zoomViewIsNotResizable;

- (void) zoomWaitingForInput;

- (void) beep;

- (void) inputSourceHasFinished: (id<ZoomViewInputSource>) inputSource;

@end

NS_ASSUME_NONNULL_END
