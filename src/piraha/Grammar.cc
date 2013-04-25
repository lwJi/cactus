#include "Piraha.hpp"

namespace piraha {

extern smart_ptr<Pattern> compile(smart_ptr<Group> g,bool ignCase,Grammar *gram);

smart_ptr<Grammar> pegGrammar = AutoGrammar::reparserGenerator();

void compile(Grammar *thisg,std::string name,smart_ptr<Group> g) {
    thisg->default_rule = name;
    smart_ptr<Pattern> p = piraha::compile(g,false,thisg);
    thisg->patterns.put(name,p);
}
void compile(Grammar *thisg,std::string name,std::string pattern) {
    thisg->default_rule = name;
    smart_ptr<Matcher> m = new Matcher(pegGrammar.ptr(),"pattern",pattern.c_str());
    if(m->matches()) {
        smart_ptr<Group> g = m->result();
        smart_ptr<Pattern> p = piraha::compile(g,false,thisg);
        thisg->patterns.put(name,p);
    } else {
        std::cout << "Could not compile(" << name << "," << pattern << ")" << std::endl;
        std::cout << "pos = " << m->pos << std::endl;
        assert(false);
    }
}

smart_ptr<Pattern> Grammar::compile(const char *pattern_name, const char *pattern_text) {
    default_rule = pattern_name;
    smart_ptr<Matcher> m = pegGrammar->matcher("pattern",pattern_text);
    smart_ptr<Pattern> p;
    if(m->matches()) {
        smart_ptr<Group> g = m->result();
        p = piraha::compile(g,false,this);
        patterns.put(pattern_name,p);
    } else {
        throw m->near();
    }
    return p;
}

smart_ptr<Matcher> Grammar::matcher(const char *text,int input_size) {
    smart_ptr<Matcher> m = new Matcher(this,default_rule.c_str(),text,input_size);
    return m;
}
smart_ptr<Matcher> Grammar::matcher(const char *pattern,const char *text,int input_size) {
    smart_ptr<Matcher> m = new Matcher(this,pattern,text,input_size);
    return m;
}

}
