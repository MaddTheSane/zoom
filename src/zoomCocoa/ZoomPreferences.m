//
//  ZoomPreferences.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Sun Dec 21 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomPreferences.h"


@implementation ZoomPreferences

// == Preference keys ==

NSString* const ZoomPreferencesHaveChangedNotification = @"ZoomPreferencesHaveChangedNotification";

static NSString* displayWarnings	= @"DisplayWarnings";
static NSString* fatalWarnings		= @"FatalWarnings";
static NSString* speakGameText		= @"SpeakGameText";
static NSString* scrollbackLength	= @"ScrollbackLength";
static NSString* confirmGameClose   = @"ConfirmGameClose";
static NSString* keepGamesOrganised = @"KeepGamesOrganised";
static NSString* autosaveGames		= @"autosaveGames";

static NSString* gameTitle			= @"GameTitle";
static NSString* interpreter		= @"Interpreter";
static NSString* glulxInterpreter	= @"GlulxInterpreter";
static NSString* revision			= @"Revision";

static NSString* fonts				= @"Fonts";
static NSString* colours			= @"Colours";
static NSString* textMargin			= @"TextMargin";
static NSString* useScreenFonts		= @"UseScreenFonts";
static NSString* useHyphenation		= @"UseHyphenation";
static NSString* useKerning			= @"UseKerning";
static NSString* useLigatures		= @"UseLigatures";

static NSString* organiserDirectory = @"organiserDirectory";

static NSString* foregroundColour   = @"ForegroundColour";
static NSString* backgroundColour   = @"BackgroundColour";
static NSString* showBorders		= @"ShowBorders";
static NSString* showGlkBorders		= @"ShowGlkBorders";
static NSString* showCoverPicture   = @"ShowCoverPicture";

// == Global preferences ==

static ZoomPreferences* globalPreferences = nil;
static NSLock*          globalLock = nil;

+ (NSString*) defaultOrganiserDirectory {
	NSArray* docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	
	NSString* res = [[docDir objectAtIndex: 0] stringByAppendingPathComponent: @"Interactive Fiction"];
	
	return res;
}

+ (void)initialize {
	@autoreleasepool {
	
    NSUserDefaults *defaults  = [NSUserDefaults standardUserDefaults];
	ZoomPreferences* defaultPrefs = [[[self class] alloc] initWithDefaultPreferences];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject: [defaultPrefs dictionary]
															forKey: @"ZoomGlobalPreferences"];
	
    [defaults registerDefaults: appDefaults];
	
	globalLock = [[NSLock alloc] init];
	
	}
}

+ (ZoomPreferences*) globalPreferences {
	[globalLock lock];
	
	if (globalPreferences == nil) {
		NSDictionary* globalDict = [[NSUserDefaults standardUserDefaults] objectForKey: @"ZoomGlobalPreferences"];
		
		if (globalDict== nil) 
			globalPreferences = [[ZoomPreferences alloc] initWithDefaultPreferences];
		else
			globalPreferences = [[ZoomPreferences alloc] initWithDictionary: globalDict];
		
		// Must contain valid fonts and colours
		if ([globalPreferences fonts] == nil || [globalPreferences colours] == nil) {
			NSLog(@"Missing element in global preferences: replacing");
			globalPreferences = [[ZoomPreferences alloc] initWithDefaultPreferences];
		}
	}
	
	[globalLock unlock];
	
	return globalPreferences;
}

// == Initialisation ==

- (id) init {
	self = [super init];
	
	if (self) {
		prefLock = [[NSLock alloc] init];
		prefs = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

static NSArray* DefaultFonts(void) {
	NSString* defaultFontName = @"Gill Sans";
	NSString* fixedFontName = @"Courier";
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	NSMutableArray* defaultFonts = [[NSMutableArray alloc] init];
	
	NSFont* variableFont = [mgr fontWithFamily: defaultFontName
										traits: NSUnboldFontMask
										weight: 5
										  size: 12];
	NSFont* fixedFont = [mgr fontWithFamily: fixedFontName
									 traits: NSUnboldFontMask
									 weight: 5
									   size: 12];
	
	if (variableFont == nil) variableFont = [NSFont systemFontOfSize: 12];
	if (fixedFont == nil) fixedFont = [NSFont userFixedPitchFontOfSize: 12];
	
	int x;
	for (x=0; x<16; x++) {
		NSFont* thisFont = variableFont;
		if ((x&4)) thisFont = fixedFont;
		
		if ((x&1)) thisFont = [mgr convertFont: thisFont
								   toHaveTrait: NSBoldFontMask];
		if ((x&2)) thisFont = [mgr convertFont: thisFont
								   toHaveTrait: NSItalicFontMask];
		if ((x&4)) thisFont = [mgr convertFont: thisFont
								   toHaveTrait: NSFixedPitchFontMask];
		
		[defaultFonts addObject: thisFont];
	}
	
	return defaultFonts;
}

static NSArray* DefaultColours(void) {
	NSArray* defaultColours = @[
		[NSColor colorWithDeviceRed: 0 green: 0 blue: 0 alpha: 1],
		[NSColor colorWithDeviceRed: 1 green: 0 blue: 0 alpha: 1],
		[NSColor colorWithDeviceRed: 0 green: 1 blue: 0 alpha: 1],
		[NSColor colorWithDeviceRed: 1 green: 1 blue: 0 alpha: 1],
		[NSColor colorWithDeviceRed: 0 green: 0 blue: 1 alpha: 1],
		[NSColor colorWithDeviceRed: 1 green: 0 blue: 1 alpha: 1],
		[NSColor colorWithDeviceRed: 0 green: 1 blue: 1 alpha: 1],
		[NSColor colorWithDeviceRed: 1 green: 1 blue: .8 alpha: 1],
		
		[NSColor colorWithDeviceRed: .73 green: .73 blue: .73 alpha: 1],
		[NSColor colorWithDeviceRed: .53 green: .53 blue: .53 alpha: 1],
		[NSColor colorWithDeviceRed: .26 green: .26 blue: .26 alpha: 1],
		];
	
	return defaultColours;
}

- (id) initWithDefaultPreferences {
	self = [self init];
	
	if (self) @autoreleasepool {
		// Defaults
		[prefs setObject: @NO
				  forKey: displayWarnings];
		[prefs setObject: @NO
				  forKey: fatalWarnings];
		[prefs setObject: @NO
				  forKey: speakGameText];
		
		[prefs setObject: @"%s (%i.%.6s.%04x)"
				  forKey: gameTitle];
		[prefs setObject: @3
				  forKey: interpreter];
		[prefs setObject: [NSNumber numberWithInt: 'Z']
				  forKey: revision];
		[prefs setObject: @(GlulxGit)
				  forKey: glulxInterpreter];
		
		[prefs setObject: DefaultFonts()
				  forKey: fonts];
		[prefs setObject: DefaultColours()
				  forKey: colours];
		
		[prefs setObject: @0
				  forKey: foregroundColour];
		[prefs setObject: @7
				  forKey: backgroundColour];
		[prefs setObject: @YES
				  forKey: showBorders];
		[prefs setObject: @YES
				  forKey: showGlkBorders];
	}
	
	return self;
}

- (id) initWithDictionary: (NSDictionary*) dict {
	self = [super init];
	
	if (self) {
		prefLock = [[NSLock alloc] init];
		prefs = [dict mutableCopy];
		
		// Fonts and colours will be archived if they exist
		NSData* fts = [prefs objectForKey: fonts];
		NSData* cols = [prefs objectForKey: colours];

		if ([fts isKindOfClass: [NSData class]]) {
			id tmp = [NSKeyedUnarchiver unarchivedObjectOfClasses: [NSSet setWithObjects: [NSArray class], [NSFont class], nil] fromData: fts error: NULL];
			if (!tmp) {
				tmp = [NSUnarchiver unarchiveObjectWithData: fts];
			}
			[prefs setObject: [NSMutableArray arrayWithArray: tmp]
					  forKey: fonts];
		}
		
		if ([cols isKindOfClass: [NSData class]]) {
			id tmp = [NSKeyedUnarchiver unarchivedObjectOfClasses: [NSSet setWithObjects: [NSArray class], [NSColor class], nil] fromData: cols error: NULL];
			if (!tmp) {
				tmp = [NSUnarchiver unarchiveObjectWithData: cols];
			}
			[prefs setObject: [NSMutableArray arrayWithArray: tmp]
					  forKey: colours];
		}
		
		// Verify that things are intact
		NSArray* newFonts = [prefs objectForKey: fonts];
		NSArray* newColours = [prefs objectForKey: colours];
		
		if (newFonts && [newFonts count] != 16) {
			NSLog(@"Unable to decode font block completely: using defaults");
			[prefs setObject: DefaultFonts()
					  forKey: fonts];
		}
		
		if (newColours && [newColours count] != 11) {
			NSLog(@"Unable to decode colour block completely: using defaults");
			[prefs setObject: DefaultColours()
					  forKey: colours];
		}
	}
	
	return self;
}

- (NSDictionary*) dictionary {
	// Fonts and colours need encoding
	NSMutableDictionary* newDict = [prefs mutableCopy];
	
	NSArray* fts = [newDict objectForKey: fonts];
	NSArray* cols = [newDict objectForKey: colours];
	
	if (fts != nil) {
		[newDict setObject: [NSKeyedArchiver archivedDataWithRootObject: fts requiringSecureCoding: YES error: NULL]
					forKey: fonts];
	}
	
	if (cols != nil) {
		[newDict setObject: [NSKeyedArchiver archivedDataWithRootObject: cols requiringSecureCoding: YES error: NULL]
					forKey: colours];
	}

	
	return newDict;
}

// Getting preferences
- (BOOL) displayWarnings {
	[prefLock lock];
	BOOL result = [[prefs objectForKey: displayWarnings] boolValue];
	[prefLock unlock];
	
	return result;
}

- (BOOL) fatalWarnings {
	[prefLock lock];
	BOOL result = [[prefs objectForKey: fatalWarnings] boolValue];
	[prefLock unlock];
	
	return result;
}

- (BOOL) speakGameText {
	[prefLock lock];
	BOOL result =  [[prefs objectForKey: speakGameText] boolValue];
	[prefLock unlock];
	
	return result;
}

- (CGFloat) scrollbackLength {
	[prefLock lock];
	
	CGFloat result;
	if ([prefs objectForKey: scrollbackLength] == nil)
		result = 100.0;
	else
		result = [[prefs objectForKey: scrollbackLength] floatValue];
	
	[prefLock unlock];
	
	return result;
}

- (BOOL) confirmGameClose {
	BOOL result = YES;
	
	[prefLock lock];
	
	NSNumber* confirmValue = (NSNumber*)[prefs objectForKey: confirmGameClose];
	if (confirmValue) result = [confirmValue boolValue];
	
	[prefLock unlock];
	
	return result;
}

- (NSString*) gameTitle {
	[prefLock lock];
	NSString* result =  [prefs objectForKey: gameTitle];
	[prefLock unlock];
	
	return result;
}

- (int) interpreter {
	[prefLock lock];
	int result = [[prefs objectForKey: interpreter] intValue];
	[prefLock unlock];
	
	return result;
}

- (GlulxInterpreter) glulxInterpreter {
	[prefLock lock];
	NSNumber* glulxInterpreterNum = (NSNumber*)[prefs objectForKey: glulxInterpreter];
	
	GlulxInterpreter result;
	if (glulxInterpreterNum)	result = [glulxInterpreterNum integerValue];
	else						result = GlulxGit;
	
	[prefLock unlock];
	
	return result;
}

- (unsigned char) revision {
	[prefLock lock];
	unsigned char result = [[prefs objectForKey: revision] unsignedCharValue];
	[prefLock unlock];
	
	return result;
}

- (NSArray*) fonts {
	[prefLock lock];
	NSArray* result = [prefs objectForKey: fonts];
	[prefLock unlock];
	
	return result;
}

- (NSArray*) colours {
	[prefLock lock];
	NSArray* result = [prefs objectForKey: colours];
	[prefLock unlock];
	
	return result;
}

- (NSString*) proportionalFontFamily {
	// Font 0 forms the prototype for this
	NSFont* prototypeFont = [[self fonts] objectAtIndex: 0];
	
	return [prototypeFont familyName];
}

- (NSString*) fixedFontFamily {
	// Font 4 forms the prototype for this
	NSFont* prototypeFont = [[self fonts] objectAtIndex: 4];
	
	return [prototypeFont familyName];
}

- (NSString*) symbolicFontFamily {
	// Font 8 forms the prototype for this
	NSFont* prototypeFont = [[self fonts] objectAtIndex: 8];
	
	return [prototypeFont familyName];
}

- (CGFloat) fontSize {
	// Font 0 forms the prototype for this
	NSFont* prototypeFont = [[self fonts] objectAtIndex: 0];
	
	return [prototypeFont pointSize];
}

- (NSString*) organiserDirectory {
	[prefLock lock];
	NSString* res = [prefs objectForKey: organiserDirectory];
	
	if (res == nil) {
		NSArray* docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		
		res = [[docDir objectAtIndex: 0] stringByAppendingPathComponent: @"Interactive Fiction"];
	}
	[prefLock unlock];
	
	return res;
}

- (CGFloat) textMargin {
	[prefLock lock];
	NSNumber* result = (NSNumber*)[prefs objectForKey: textMargin];
	if (result == nil) result = @10.0;
	[prefLock unlock];
	
	return [result floatValue];
}

- (BOOL) useScreenFonts {
	[prefLock lock];
	NSNumber* num = [prefs objectForKey: useScreenFonts];
	BOOL result;
	
	if (num)
		result = [num boolValue];
	else
		result = YES;
	[prefLock unlock];
	
	return result;
}

- (BOOL) useHyphenation {
	[prefLock lock];
	NSNumber* num = [prefs objectForKey: useHyphenation];
	BOOL result;
	
	if (num)
		result = [num boolValue];
	else
		result = YES;
	[prefLock unlock];
	
	return result;	
}

- (BOOL) useKerning {
	[prefLock lock];
	NSNumber* num = [prefs objectForKey: useKerning];
	BOOL result;
	
	if (num)
		result = [num boolValue];
	else
		result = YES;
	[prefLock unlock];
	
	return result;	
}

- (BOOL) useLigatures {
	[prefLock lock];
	NSNumber* num = [prefs objectForKey: useLigatures];
	BOOL result;
	
	if (num)
		result = [num boolValue];
	else
		result = YES;
	[prefLock unlock];
	
	return result;		
}

- (BOOL) keepGamesOrganised {
	[prefLock lock];
	BOOL result = [[prefs objectForKey: keepGamesOrganised] boolValue];
	[prefLock unlock];
	
	return result;
}

- (BOOL) autosaveGames {
	[prefLock lock];
	NSNumber* autosave = [prefs objectForKey: autosaveGames];
	
	BOOL result = NO;			// Changed from 1.0.2beta1 as this was annoying
	if (autosave) result = [autosave boolValue];
	[prefLock unlock];
	
	return result;
}

// Setting preferences
- (void) setDisplayWarnings: (BOOL) flag {
	[prefs setObject: @(flag)
			  forKey: displayWarnings];
	[self preferencesHaveChanged];
}

- (void) setFatalWarnings: (BOOL) flag {
	[prefs setObject: @(flag)
			  forKey: fatalWarnings];
	[self preferencesHaveChanged];
}

- (void) setSpeakGameText: (BOOL) flag {
	[prefs setObject: @(flag)
			  forKey: speakGameText];
	[self preferencesHaveChanged];
}

- (void) setScrollbackLength: (CGFloat) length {
	[prefs setObject: @(length)
			  forKey: scrollbackLength];
	[self preferencesHaveChanged];
}

- (void) setConfirmGameClose: (BOOL) flag {
	[prefs setObject: @(flag)
			  forKey: confirmGameClose];
	[self preferencesHaveChanged];
}

- (void) setGameTitle: (NSString*) title {
	[prefs setObject: [title copy]
			  forKey: gameTitle];
	[self preferencesHaveChanged];
}

- (void) setGlulxInterpreter: (GlulxInterpreter) value {
	[prefs setObject: @(value)
			  forKey: glulxInterpreter];
	[self preferencesHaveChanged];
}

- (void) setInterpreter: (int) inter {
	[prefs setObject: @(inter)
			  forKey: interpreter];
	[self preferencesHaveChanged];
}

- (void) setRevision: (unsigned char) rev {
	[prefs setObject: @(rev)
			  forKey: revision];
	[self preferencesHaveChanged];
}

- (void) setFonts: (NSArray*) fts {
	[prefs setObject: [NSArray arrayWithArray: fts]
			  forKey: fonts];
	[self preferencesHaveChanged];
}

- (void) setColours: (NSArray*) cols {
	[prefs setObject: [NSArray arrayWithArray: cols]
			  forKey: colours];
	[self preferencesHaveChanged];
}

- (void) setOrganiserDirectory: (NSString*) directory {
	if (directory != nil) {
		[prefs setObject: directory
				  forKey: organiserDirectory];
	} else {
		[prefs removeObjectForKey: organiserDirectory];
	}
	[self preferencesHaveChanged];
}

- (void) setKeepGamesOrganised: (BOOL) value {
	[prefs setObject: @(value)
			  forKey: keepGamesOrganised];
	[self preferencesHaveChanged];
}

- (void) setAutosaveGames: (BOOL) value {
	[prefs setObject: @(value)
			  forKey: autosaveGames];
	[self preferencesHaveChanged];
}

- (void) setTextMargin: (CGFloat) value {
	[prefs setObject: @(value)
			  forKey: textMargin];
	[self preferencesHaveChanged];
}

- (void) setUseScreenFonts: (BOOL) value {
	[prefs setObject: @(value)
			  forKey: useScreenFonts];
	[self preferencesHaveChanged];
}

- (void) setUseHyphenation: (BOOL) value {
	[prefs setObject: @(value)
			  forKey: useHyphenation];
	[self preferencesHaveChanged];
}

- (void) setUseKerning: (BOOL) value {
	[prefs setObject: @(value)
			  forKey: useKerning];
	[self preferencesHaveChanged];	
}

- (void) setUseLigatures: (BOOL) value {
	[prefs setObject: @(value)
			  forKey: useLigatures];
	[self preferencesHaveChanged];	
}

- (void) setFontRange: (NSRange) fontRange
			 toFamily: (NSString*) newFontFamily {
	// Sets a given range of fonts to the given family
	CGFloat size = [self fontSize];
	
	NSMutableArray* newFonts = [[self fonts] mutableCopy];
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	NSInteger x;
	for (x=fontRange.location; x<fontRange.location+fontRange.length; x++) {
		// Get the traits for this font
		NSFontTraitMask traits = 0;
		
		if (x&1) traits |= NSBoldFontMask;
		if (x&2) traits |= NSItalicFontMask;
		if (x&4) traits |= NSFixedPitchFontMask;
		
		// Get a suitable font
		NSFont* newFont = [mgr fontWithFamily: newFontFamily
									   traits: traits
									   weight: 5
										 size: size];
		
		if (!newFont || [[newFont familyName] caseInsensitiveCompare: newFontFamily] != NSEqualToComparison) {
			// Retry with simpler conditions if we fail to get a font for some reason
			newFont = [mgr fontWithFamily: newFontFamily
								   traits: (x&4)!=0?NSFixedPitchFontMask:0
								   weight: 5
									 size: size];
		}
		
		// Store it
		if (newFont) {
			[newFonts replaceObjectAtIndex: x
								withObject: newFont];
		}
	}
	
	[self setFonts: newFonts];
}

- (void) setProportionalFontFamily: (NSString*) fontFamily {
	[self setFontRange: NSMakeRange(0,4)
			  toFamily: fontFamily];
}

- (void) setFixedFontFamily: (NSString*) fontFamily {
	[self setFontRange: NSMakeRange(4,4)
			  toFamily: fontFamily];
}

- (void) setSymbolicFontFamily: (NSString*) fontFamily {
	[self setFontRange: NSMakeRange(8,8)
			  toFamily: fontFamily];
}

- (void) setFontSize: (CGFloat) size {
	// Change the font size of all the fonts
	NSMutableArray* newFonts = [NSMutableArray array];
	
	NSFontManager* mgr = [NSFontManager sharedFontManager];
	
	for (NSFont* font in [self fonts]) {
		NSFont* newFont = [mgr convertFont: font
									toSize: size];
		
		if (newFont) {
			[newFonts addObject: newFont];
		} else {
			[newFonts addObject: font];
		}
	}
	
	// Store the results
	[self setFonts: newFonts];
}

// = Display preferences =

- (int) foregroundColour {
	NSNumber* val = [prefs objectForKey: foregroundColour];
	if (val == nil) return 0;
	return [val intValue];
}

- (int) backgroundColour {
	NSNumber* val = [prefs objectForKey: backgroundColour];
	if (val == nil) return 7;
	return [val intValue];	
}

- (BOOL) showCoverPicture {
	NSNumber* val = [prefs objectForKey: showCoverPicture];
	if (val == nil) return YES;
	return [val boolValue];	
}

- (BOOL) showBorders {
	NSNumber* val = [prefs objectForKey: showBorders];
	if (val == nil) return YES;
	return [val boolValue];
}

- (BOOL) showGlkBorders {
	NSNumber* val = [prefs objectForKey: showGlkBorders];
	if (val == nil) return YES;
	return [val boolValue];	
}

- (void) setShowCoverPicture: (BOOL) value {
	[prefs setObject: @(value)
			  forKey: showCoverPicture];
	[self preferencesHaveChanged];	
}

- (void) setShowBorders: (BOOL) value {
	[prefs setObject: @(value)
			  forKey: showBorders];
	[self preferencesHaveChanged];	
}

- (void) setShowGlkBorders: (BOOL) value {
	[prefs setObject: @(value)
			  forKey: showGlkBorders];
	[self preferencesHaveChanged];	
}

- (void) setForegroundColour: (int) value {
	[prefs setObject: @(value)
			  forKey: foregroundColour];
	[self preferencesHaveChanged];		
}

- (void) setBackgroundColour: (int) value {
	[prefs setObject: @(value)
			  forKey: backgroundColour];
	[self preferencesHaveChanged];	
}

// = Notifications =

- (void) preferencesHaveChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName: ZoomPreferencesHaveChangedNotification
														object:self];
	
	if (self == globalPreferences) {
		// Save global preferences
		[[NSUserDefaults standardUserDefaults] setObject:[self dictionary] 
												  forKey:@"ZoomGlobalPreferences"];		
	}
}

// = NSCoding =
- (id) initWithCoder: (NSCoder*) coder {
	self = [super init];
	
	if (self) {
		if (coder.allowsKeyedCoding) {
			prefs = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [NSColor class], [NSFont class], [NSArray class], [NSNumber class], nil] forKey: @"prefs"];
		} else {
			prefs = [coder decodeObject];
		}
	}
	
	return self;
}

- (void) encodeWithCoder: (NSCoder*) coder {
	if (coder.allowsKeyedCoding) {
		[coder encodeObject: prefs forKey: @"prefs"];
	} else {
		[coder encodeObject: prefs];
	}
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

@end
