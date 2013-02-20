#include "Piraha.hpp"

extern smart_ptr<Pattern> compile(smart_ptr<Group> g,bool ignCase,smart_ptr<Grammar> gram);

smart_ptr<Grammar> pegGrammar = AutoGrammar::reparserGenerator();

void Grammar::compile(std::string name,smart_ptr<Group> g) {
    default_rule = name;
    smart_ptr<Pattern> p = ::compile(g,false,this);
    patterns.put(name,p);
}
void Grammar::compile(std::string name,std::string pattern) {
    default_rule = name;
    smart_ptr<Matcher> m = new Matcher(pegGrammar,"pattern",pattern.c_str());
    smart_ptr<Group> g = m.dup<Group>();
    if(m->matches()) {
        smart_ptr<Pattern> p = ::compile(g,false,this);
        patterns.put(name,p);
    } else {
        std::cout << "Could not compile(" << name << "," << pattern << ")" << std::endl;
        std::cout << "pos = " << m->pos << std::endl;
        assert(false);
    }
}
