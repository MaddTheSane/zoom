//
//  ZoomPreferences.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Dec 21 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

extern NSString* ZoomPreferencesHaveChangedNotification;

typedef NS_ENUM(NSInteger, GlulxInterpreter) {
	GlulxGit		= 0,
	GlulxGlulxe		= 1
};

@interface ZoomPreferences : NSObject<NSCoding> {
	NSMutableDictionary<NSString*,id>* prefs;
	NSLock* prefLock;
}

// init is the designated initialiser for this class
- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithCoder: (NSCoder*) coder NS_DESIGNATED_INITIALIZER;

+ (ZoomPreferences*) globalPreferences;
@property (class, readonly, retain) ZoomPreferences* globalPreferences;
- (instancetype) initWithDefaultPreferences;

- (instancetype) initWithDictionary: (NSDictionary<NSString*,id>*) preferences NS_DESIGNATED_INITIALIZER;

// Getting preferences
+ (NSString*) defaultOrganiserDirectory;
@property (class, readonly, retain) NSString* defaultOrganiserDirectory;

// Warnings and game text prefs
@property (nonatomic) BOOL displayWarnings;
@property (nonatomic) BOOL fatalWarnings;
@property (nonatomic) BOOL speakGameText;
@property (nonatomic) BOOL confirmGameClose;
@property (nonatomic) CGFloat scrollbackLength;	//!< 0-100

// Interpreter preferences
@property (nonatomic, copy) NSString *gameTitle;
@property (nonatomic) int interpreter;
@property (nonatomic) GlulxInterpreter glulxInterpreter;
@property (nonatomic) unsigned char revision;

// Typographical preferences
@property (nonatomic, copy) NSArray<NSFont*> *fonts;   //!< 16 fonts
@property (nonatomic, copy) NSArray<NSColor*> *colours; //!< 13 colours

@property (nonatomic, copy) NSString *proportionalFontFamily;
@property (nonatomic, copy) NSString *fixedFontFamily;
@property (nonatomic, copy) NSString *symbolicFontFamily;
@property (nonatomic) CGFloat fontSize;

@property (nonatomic) CGFloat textMargin;
@property (nonatomic) BOOL useScreenFonts;
@property (nonatomic) BOOL useHyphenation;

@property (nonatomic) BOOL useKerning;
@property (nonatomic) BOOL useLigatures;

// Organiser preferences
@property (nonatomic, retain) NSString *organiserDirectory;
@property (nonatomic) BOOL keepGamesOrganised;
@property (nonatomic) BOOL autosaveGames;

// Display preferences
@property (nonatomic) int foregroundColour;
@property (nonatomic) int backgroundColour;
@property (nonatomic) BOOL showBorders;
@property (nonatomic) BOOL showGlkBorders;
@property (nonatomic) BOOL showCoverPicture;

// The dictionary
@property (readonly, copy) NSDictionary<NSString*,id> *dictionary;

// Setting preferences
- (void) setDisplayWarnings: (BOOL) flag;
- (void) setFatalWarnings: (BOOL) flag;
- (void) setSpeakGameText: (BOOL) flag;
- (void) setConfirmGameClose: (BOOL) flag;
- (void) setScrollbackLength: (CGFloat) value;
- (void) setGlulxInterpreter: (GlulxInterpreter) value;

- (void) setGameTitle: (NSString*) title;
- (void) setInterpreter: (int) interpreter;
- (void) setRevision: (unsigned char) revision;

- (void) setFonts: (NSArray<NSFont*>*) fonts;
- (void) setColours: (NSArray<NSColor*>*) colours;

- (void) setProportionalFontFamily: (NSString*) fontFamily;
- (void) setFixedFontFamily: (NSString*) fontFamily;
- (void) setSymbolicFontFamily: (NSString*) fontFamily;
- (void) setFontSize: (CGFloat) size;

- (void) setTextMargin: (CGFloat) textMargin;
- (void) setUseScreenFonts: (BOOL) useScreenFonts;
- (void) setUseHyphenation: (BOOL) useHyphenation;
- (void) setUseKerning: (BOOL) useKerning;
- (void) setUseLigatures: (BOOL) useLigatures;

- (void) setOrganiserDirectory: (NSString*) directory;
- (void) setKeepGamesOrganised: (BOOL) value;
- (void) setAutosaveGames: (BOOL) value;

- (void) setShowBorders: (BOOL) value;
- (void) setShowGlkBorders: (BOOL) value;
- (void) setForegroundColour: (int) value;
- (void) setBackgroundColour: (int) value;
- (void) setShowCoverPicture: (BOOL) value;

// Notifications
- (void) preferencesHaveChanged;

@end
