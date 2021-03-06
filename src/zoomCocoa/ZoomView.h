//
//  ZoomView.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>
#import "ZoomProtocol.h"
#import "ZoomMoreView.h"
#import "ZoomTextView.h"
#import "ZoomScrollView.h"
#import "ZoomPreferences.h"
#import "ZoomCursor.h"
#import "ZoomInputLine.h"
#import "ZoomBlorbFile.h"
#import "ZoomTextToSpeech.h"
#import "ZoomViewProtocols.h"

typedef NS_OPTIONS(unsigned int, ZFontStyle) {
	ZBoldStyle = 1,
	ZUnderlineStyle = 2,
	ZFixedStyle = 4,
	ZSymbolicStyle = 8
};

extern NSAttributedStringKey const ZoomStyleAttributeName;
@protocol ZoomViewDelegate;

@class ZoomScrollView;
@class ZoomTextView;
@class ZoomPixmapWindow;
@class ZoomLowerWindow;
@class ZoomUpperWindow;
@interface ZoomView : NSView <ZDisplay, NSCoding, NSTextStorageDelegate, NSTextViewDelegate, NSOpenSavePanelDelegate, ZoomCursorDelegate, ZoomInputLineDelegate> {
    NSObject<ZMachine>* zMachine;

    // Subviews
	BOOL editingTextView;
	BOOL willScrollToEnd;
	BOOL willDisplayMore;
    ZoomTextView* textView;
    NSTextContainer* upperWindowBuffer; // Things hidden under the upper window
    ZoomScrollView* textScroller;

    NSInteger inputPos;
    BOOL receiving;
    BOOL receivingCharacters;

    double morePoint;
    double moreReferencePoint;
    BOOL moreOn;

    ZoomMoreView* moreView;

    NSArray<NSFont*>* fonts; // 16 entries
	NSArray<NSFont*>* originalFonts;			//!< As for fonts, used to cache the 'original' font definitions when scaling is in effect
    NSArray<NSColor*>* colours; // 11 entries

    NSMutableArray<ZoomUpperWindow*>* upperWindows;
    NSMutableArray<ZoomLowerWindow*>* lowerWindows; // Not that more than one makes any sort of sense
    int lastUpperWindowSize;
    int lastTileSize;
    BOOL upperWindowNeedsRedrawing;

    BOOL exclusiveMode;

    // The task, if we're running it
    NSTask* zoomTask;
    NSPipe* zoomTaskStdout;
    NSMutableString* zoomTaskData;

    // The delegate
    __weak id<ZoomViewDelegate> delegate;
    
    // Details about the file we're currently saving
    OSType creatorCode; // 'YZZY' for Zoom
    OSType typeCode;
	
	// Preferences
	ZoomPreferences* viewPrefs;
	
	CGFloat scaleFactor;
	
	// Command history
	NSMutableArray* commandHistory;
	NSInteger		historyPos;
	
	// Terminating characters
	NSSet<NSNumber*>* terminatingChars;
	
	// View with input focus
	__unsafe_unretained NSObject<ZWindow>* focusedView;
	
	// Pixmap view
	ZoomCursor*       pixmapCursor;
	ZoomPixmapWindow* pixmapWindow;
	
	// Manual input
	ZoomInputLine*    inputLine;
	NSPoint			  inputLinePos;
	
	// Autosave
	NSData* lastAutosave;
	NSInteger	upperWindowsToRestore;
	BOOL	restoring;
	
	// Output receivers
	NSMutableArray<id<ZoomViewOutputReceiver>>* outputReceivers;
	ZoomTextToSpeech* textToSpeechReceiver;
	
	//! Input source
	id<ZoomViewInputSource> inputSource;
	
	//! Resources
	ZoomBlorbFile* resources;
}

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
- (void) runNewServer: (NSString*) serverName;
@property (nonatomic, strong) NSObject<ZMachine> *zMachine;

// Scrolling, more prompt
- (void) scrollToEnd;
- (void) resetMorePrompt;
- (void) updateMorePrompt;

- (void) setShowsMorePrompt: (BOOL) shown;
- (void) displayMoreIfNecessary;
- (void) page;

- (void) retileUpperWindowIfRequired;

// Formatting a string
- (NSDictionary<NSAttributedStringKey,id>*) attributesForStyle: (ZStyle*) style;
- (NSAttributedString*) formatZString: (NSString*) zString
                            withStyle: (ZStyle*) style;

@property (readonly, strong) ZoomTextView *textView;
- (void) writeAttributedString: (NSAttributedString*) string;
- (void) clearLowerWindowWithStyle: (ZStyle*) style;

// Setting the focused view
@property (assign) NSObject<ZWindow> *focusedView;

// Dealing with the history
- (NSString*) lastHistoryItem;
- (NSString*) nextHistoryItem;

// Fonts, colours, etc
- (NSFont*) fontWithStyle: (ZFontStyle) style;
- (NSColor*) foregroundColourForStyle: (ZStyle*) style;
- (NSColor*) backgroundColourForStyle: (ZStyle*) style;

- (void) setFonts:   (NSArray<NSFont*>*) fonts;
- (void) setColours: (NSArray<NSColor*>*) colours;

// File saving
@property OSType creatorCode;

// The upper window
@property (readonly) int upperWindowSize;
- (void) setUpperBuffer: (CGFloat) bufHeight;
- (CGFloat) upperBufferHeight;
- (void) rearrangeUpperWindows;
@property (readonly, copy) NSArray<ZoomUpperWindow*> *upperWindows;
- (void) padToLowerWindow;

- (void) upperWindowNeedsRedrawing;

// Event handling
- (BOOL) handleKeyDown: (NSEvent*) theEvent;
- (void) clickAtPointInWindow: (NSPoint) windowPos
					withCount: (NSInteger) count;

// Setting/updating preferences
- (void) setPreferences: (ZoomPreferences*) prefs;
- (void) preferencesHaveChanged: (NSNotification*)noti;

- (void) reformatWindow;

// Autosaving
- (BOOL) createAutosaveDataWithCoder: (NSCoder*) encoder;
- (void) restoreAutosaveFromCoder: (NSCoder*) decoder;

- (BOOL) isRunning;

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

- (ZoomTextToSpeech*) textToSpeech;

// Input sources (nil = default, window input source)
@property (nonatomic, strong) id<ZoomViewInputSource> inputSource;
- (void) removeInputSource: (id<ZoomViewInputSource>) source;

//! Resources
@property (strong) ZoomBlorbFile *resources;

//! Terminating characters
@property (copy) NSSet<NSNumber*> *terminatingCharacters;


- (void) endOfLineReached: (ZoomInputLine*) sender;
@end

//! ZoomView delegate methods
@protocol ZoomViewDelegate <NSObject>
@optional

- (void) zMachineStarted: (id) sender;
- (void) zMachineFinished: (id) sender;

- (NSString*) defaultSaveDirectory;
- (BOOL)      useSavePackage;
- (void)      prepareSavePackage: (ZPackageFile*) file;
- (void)	  loadedSkeinData: (NSData*) skeinData;

- (void) hitBreakpoint: (int) pc;

- (void) zoomViewIsNotResizable;

- (void) zoomWaitingForInput;

- (void) beep;

- (void) inputSourceHasFinished: (id<ZoomViewInputSource>) inputSource;

@end
