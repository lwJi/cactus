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
pir_matcher_t_::~pir_matcher_t_() {
    Matcher *m = (Matcher*)pir_handle;
    delete m;
}
pir_grammar_t_::~pir_grammar_t_() {
    Grammar *g = (Grammar*)pir_handle;
    delete g;
}

void pir_free_grammar(pir_grammar_t *gram) {
    delete gram;
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
    delete matcher;
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

std::string pir_group_t_::get_str() {
    Group *g = (Group *)pir_handle;
    return g->substring();
}

pir_group_t_ pir_group_t_::child(int n) {
    pir_group_t_ g;
    pir_get_group(this,n,&g);
    return g;
}
void pir_group_t_::child(int n,pir_group_t_ *g) {
    pir_get_group(this,n,g);
}
int pir_grammar_t_::compile(
        const char *pattern_name,
        const char *pattern) {
    return pir_compile(this,pattern_name,pattern);
}
int pir_grammar_t_::compile_file(
        const char *file_contents) {
    return pir_compile_file(this,file_contents);
}
pir_grammar_t_::pir_grammar_t_() {
    pir_handle = new Grammar();
}
int pir_matcher_t_::matches(pir_group_t_ *gr) {
    return pir_matches(this,gr);
}
