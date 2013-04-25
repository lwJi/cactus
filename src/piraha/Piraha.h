#ifndef PIRAHA_H
#define PIRAHA_H
// C/C++ user interface to Piraha

#ifdef __cplusplus
#include <string>
extern "C" {
class pir_group_t_;
#endif

// Global flags
extern int pir_compile_errors_are_fatal;
extern int pir_match_errors_are_fatal;
extern int pir_print_compile_errors;
extern int pir_print_match_errors;

typedef struct pir_grammar_t_ {
    void *pir_handle;
#ifdef __cplusplus
    pir_grammar_t_();
#endif
} pir_grammar_t;

typedef struct pir_matcher_t_ {
    void *pir_handle;
#ifdef __cplusplus
    pir_matcher_t_() : pir_handle(0) {}
    pir_matcher_t_(pir_grammar_t *gram,const char *pattern,const char *text);
#endif
} pir_matcher_t;

typedef struct pir_group_t_ {
    const char *pir_name;
    int pir_start;
    int pir_end;
    int pir_line;
    int pir_ngroups;
    const char *pir_text;
    void *pir_handle;
} pir_group_t;

// Create/Free a grammar
pir_grammar_t *pir_alloc_grammar();
void pir_free_grammar(pir_grammar_t* gram);

// Compile an individual pattern
// Return is -1 on success, error 
// position in string on failure
int pir_compile(
    pir_grammar_t *gram,
    const char *pattern_name,
    const char *pattern);

// Compile a whole grammar file
// Return is -1 on success, error 
// position in string on failure
int pir_compile_file(
    pir_grammar_t *gram,
    const char *file_contents);

// Create a matcher
pir_matcher_t *pir_alloc_matcher(pir_grammar_t *gram,const char *pattern,const char *text);

// Attempt to see whether a string matches
int pir_matches(
    pir_matcher_t *matcher,
    pir_group_t *group);

// Free a matcher
void pir_free_matcher(pir_matcher_t *matcher);

// Routines for looking at groups
// Get a child group
int pir_get_group(pir_group_t *parent,int n,pir_group_t *child);
// Get the substring string from the original input text
int pir_get_str(pir_group_t *group,char *buf);

// Report on an error
int pir_error(pir_matcher_t *m,char *expected);

#ifdef __cplusplus
}
#endif

#endif
