/* glkstart.c: Unix-specific startup code -- sample file.
	Designed by Andrew Plotkin <erkyrath@netcom.com>
	http://www.eblong.com/zarf/glk/index.html

	This is Unix startup code for the simplest possible kind of Glk
	program -- no command-line arguments; no startup files; no nothing.

	Remember, this is a sample file. You should copy it into the Glk
	program you are compiling, and modify it to your needs. This should
	*not* be compiled into the Glk library itself.
*/

#include <stdio.h>
#include <string.h>
#include <stdarg.h>

#include <GlkView/glk.h>
#include <GlkClient/cocoaglk.h>
#include "heheader.h"


int main(int argv, const char** argc) {
	// Get everything running
	cocoaglk_start(argv, argc);
	cocoaglk_log("CocoaGlk Hugo interpreter is starting");
	{
		char versInfo[40];
		snprintf(versInfo, sizeof(versInfo), "Hugo interpreter version %i.%i%s", HEVERSION, HEREVISION, HEINTERIM);
		cocoaglk_log_ex(versInfo, 1);
	}
	
	// Get the game file that we'll be using
	game = cocoaglk_get_input_stream();
	if (game == NULL) {
		frefid_t gameref = glk_fileref_create_by_prompt(fileusage_cocoaglk_GameFile, filemode_Read, 0);
		
		if (gameref == NULL) {
			cocoaglk_error("No game file supplied");
			exit(1);
		}
		
		game = glk_stream_open_file(gameref, filemode_Read, 0);
	}
	
	if (game == NULL) {
		cocoaglk_error("Failed to open the game file");
		exit(1);
	}
	
	// Memory-ify the file (FIXME: implement a proper buffered stream class - ie, read buffering)
	glk_stream_set_position(game, 0, seekmode_End);
	int length = glk_stream_get_position(game);
	
	unsigned char* data = malloc(length);
	glk_stream_set_position(game, 0, seekmode_Start);
	glk_get_buffer_stream(game, (char*)data, length);
	
	game = glk_stream_open_memory((char*)data, length, filemode_Read, 0);
	
	// Pass off control
	glk_main();
	
	// Finish up
	cocoaglk_log("Finishing normally");
	cocoaglk_flushbuffer("About to finish");
	glk_exit();
	
	return 0;
}
