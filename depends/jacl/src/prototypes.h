/* prototypes.h --- Shared interfaces used by CGIJACL and JACL
 * (C) 2008 Stuart Allen, distribute and use 
 * according to GNU GPL, see file COPYING for details.
 */

#include <GlkView/glk.h>
#include "types.h"

#ifdef GLK
strid_t open_glk_file(glui32 usage, glui32 mode, const char *filename);
glui32 glk_get_bin_line_stream(strid_t file_stream, char *buffer, glui32 max_length); 
#else
void update_parameters();
#endif

#ifdef GARGLK
extern char* garglk_fileref_get_name(frefid_t fref);

extern void garglk_set_program_name(const char *name);
extern void garglk_set_program_info(const char *info);
extern void garglk_set_story_name(const char *name);
extern void garglk_set_config(const char *name);
#endif

void default_footer(void);
void default_header(void);
int validate(const char *string);
int is_direct_child_of_from(int child);
int scope(int index, const char *expected, int restricted);
int object_element_resolve(const char *testString);
int execute(const char *funcname);
int object_resolve(const char *object_string);
int random_number(void);
void log_access(const char *message);
void log_error(const char *message, int console);
int parent_of(int parent, int child, int restricted);
int check_light(int where);
int find_route(int fromRoom, int toRoom, int known);
void undoing(void);
void create_paths(char *full_path);
int get_key(void);
char get_character(const char *message);
int get_yes_or_no(void);
void get_string(char *string_buffer);
int get_number(int insist, int low, int high);
int save_interaction(const char *filename);
int restore_interaction(const char *filename);
void jacl_encrypt (char *string);
void jacl_decrypt (char *string);
void log_message(const char *message, int console);
void set_them(int noun_number);
void preparse(void);
long value_of(const char *value, int run_time);
long attribute_resolve(const char *attribute);
long user_attribute_resolve(const char *name);
struct word_type *exact_match(struct word_type *pointer);
struct word_type *object_match(struct word_type *iterator, int noun_number);
struct integer_type *integer_resolve(const char *name);
struct integer_type *integer_resolve_indexed(const char *name, int index);
struct function_type *function_resolve(const char *name);
struct string_type *string_resolve(const char *name);
struct string_type *string_resolve_indexed(const char *name, int index);
struct string_type *cstring_resolve(const char *name);
struct string_type *cstring_resolve_indexed(const char *name, int index);
struct cinteger_type *cinteger_resolve(const char *name);
struct cinteger_type *cinteger_resolve_indexed(const char *name, int index);
int array_length_resolve(const char *testString);
//int attribute_test();
char* object_names(int object_index, char *names_buffer);
const char* arg_text_of(const char *string);
const char* arg_text_of_word(int wordnumber);
const char* var_text_of_word(int wordnumber);
const char* text_of(const char *string);
const char* text_of_word(int wordnumber);
const char* expand_function(const char *name);
int* container_resolve(const char *container_name);
int condition(void);
int and_condition(void);
void word_check(void);
void eachturn(void);
int jacl_whitespace(int character);
int get_here(void);
char* stripwhite(char *string);
void command_encapsulate(void);
void encapsulate(void);
void jacl_truncate(void);
void parser(void);
void look_around(void);
char* macro_resolve(const char *testString);
char* plain_output(int index, int capital);
char* sub_output(int index, int capital);
char* obj_output(int index, int capital);
char* that_output(int index, int capital);
char* sentence_output(int index, int capital);
char* isnt_output(int index);
char* is_output(int index);
char* it_output(int index);
char* doesnt_output(int index);
char* does_output(int index);
char* list_output(int index, int capital);
char* long_output(int index);
void terminate(int code);
void write_text(const char *string_buffer);
void status_line(void);
void newline(void);
//void scroll();
int  save_game(frefid_t saveref);
int  restore_game(frefid_t saveref, int warn);
void save_game_state(void);
void restore_game_state(void);
//void add_string();
void add_cstring(const char *name, const char *value);
//void clear_string();
void clear_cstring(const char *name);
void add_cinteger(const char *name, int value);
void clear_cinteger(const char *name);
void restart_game(void);
void read_gamefile(void);
void unkvalerr(int line, int wordno);
void totalerrs(int errors);
void unkatterr(int line, int wordno);
void unkfunrun(char *name);
void nofnamerr(int line);
void nongloberr(int line);
void unkkeyerr(int line, int wordno);
void maxatterr(int line, int wordno);
void unkattrun(int wordno);
void badptrrun(const char *name, int value);
void badplrrun(int value);
void badparrun(void);
void notintrun(void);
void noproprun(void);
void noproperr(int line);
void noobjerr(int line);
void unkobjerr(int line, int wordno);
void unkobjrun(int wordno);
void unkdirrun(int wordno);
void unkscorun(const char *scope);
void unkstrrun(const char *variable);
void unkvarrun(const char *variable);
void outofmem(void);
void no_it(void);
void clrscrn(void);
void more(const char* message);
int jpp(void);
char* strip_return(char *string);
char** command_completion(char* text, int start, int end);
void add_word(char * word);
void jacl_sleep(unsigned int mseconds);
