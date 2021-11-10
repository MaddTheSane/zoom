//
//  ZoomPreferences.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Dec 21 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import <AppKit/AppKit.h>

extern NSNotificationName const ZoomPreferencesHaveChangedNotification;

typedef NS_ENUM(NSInteger, GlulxInterpreter) {
	GlulxGit		= 0,
	GlulxGlulxe		= 1
};

@interface ZoomPreferences : NSObject<NSSecureCoding, NSCopying> {
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
@property (class, readonly, copy) NSString* defaultOrganiserDirectory;

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
@property (nonatomic, copy) NSString *organiserDirectory;
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

// Notifications
- (void) preferencesHaveChanged;

@end
