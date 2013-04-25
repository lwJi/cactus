#include "Piraha.h"
#include "Piraha.hpp"
#include <string.h>
#include <stdio.h>
#include <sstream>

using namespace piraha;

pir_grammar_t *pir_alloc_grammar() {
    return new pir_grammar_t();
}

pir_matcher_t *pir_alloc_matcher(pir_grammar_t *gram,const char *pattern,const char *text) {
    return new pir_matcher_t_(gram,pattern,text);
}

pir_matcher_t_::pir_matcher_t_(pir_grammar_t *gram,const char *pattern,const char *text) {
    Grammar *g = (Grammar*)gram->pir_handle;
    if(pattern == 0)
        pattern = g->default_rule.c_str();
    Matcher *m = new Matcher(g,pattern,text);
    pir_handle = m;
}

void pir_free_grammar(pir_grammar_t *gram) {
    Grammar *g = (Grammar*)gram->pir_handle;
    delete g;
}

int pir_compile(pir_grammar_t *gram,const char *pattern_name,const char *pattern) {
    Grammar *g = (Grammar*)gram->pir_handle;
    unsigned int sz = strlen(pattern);
    return compilePattern(g,pattern_name,pattern,sz);
}

int pir_compile_file(pir_grammar_t *gram, const char *file_contents) {
    Grammar *g = (Grammar*)gram->pir_handle;
    return compileFile(g,file_contents);
}

void pir_free_matcher(pir_matcher_t *matcher) {
    Matcher *m = (Matcher*)matcher->pir_handle;
    delete m;
}

int pir_matches(
    pir_matcher_t *matcher,
    pir_group_t *group)
{
    Matcher *m = (Matcher *)matcher->pir_handle;
    if(m->matches()) {
        group->pir_handle = m;
        group->pir_start = m->start();
        group->pir_end = m->end();
        group->pir_line = m->line();
        group->pir_name = m->getPatternName().c_str();
        group->pir_ngroups = m->children.size();
        return 1;
    } else {
        if(pir_match_errors_are_fatal
        || pir_print_match_errors) m->showError();
        if(pir_match_errors_are_fatal) assert(0);
        return 0;
    }
}

int pir_get_group(pir_group_t *parent,int n,pir_group_t *child) {
    Group *par = (Group *)parent->pir_handle;
    if(n >= parent->pir_ngroups)
        return -1;
    smart_ptr<Group> ch = par->children[n];
    child->pir_handle = ch.ptr();
    child->pir_start = ch->start();
    child->pir_end = ch->end();
    child->pir_line = ch->line();
    child->pir_name = ch->getPatternName().c_str();
    child->pir_ngroups = ch->children.size();
    return 1;
}

int pir_get_str(pir_group_t *group,char *buf) {
    Group *g = (Group *)group->pir_handle;
    const char *iter = g->input+g->start();
    const char *end = g->input+g->end();
    while(iter < end) {
        *buf++ = *iter++;
    }
    *buf = '\0';
    return 1;
}

int pir_error(pir_matcher_t *matcher,char *expected) {
    Matcher *m = (Matcher *)matcher->pir_handle;
    if(expected != 0) {
        std::ostringstream os;
        m->expected_.insert(os);
        strcpy(expected,os.str().c_str());
    }
    return m->err_pos;
}

pir_grammar_t_::pir_grammar_t_() {
    pir_handle = new Grammar();
}
