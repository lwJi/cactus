#include "Piraha.hpp"
#include <sstream>

namespace cctki_piraha {

extern std::shared_ptr<Pattern> compile(std::shared_ptr<Group> g,bool ignCase,std::shared_ptr<Grammar> gram);

std::shared_ptr<Grammar> pegGrammar = AutoGrammar::reparserGenerator();

void compile(std::shared_ptr<Grammar> thisg,std::string name,std::shared_ptr<Group> g) {
    thisg->default_rule = name;
    std::shared_ptr<Pattern> p = cctki_piraha::compile(g,false,thisg);
    thisg->patterns.put(name,p);
}
void compile(std::shared_ptr<Grammar> thisg,std::string name,std::string pattern) {
    thisg->default_rule = name;
    std::shared_ptr<Matcher> m = std::make_shared<Matcher>(pegGrammar,"pattern",pattern.c_str());
    std::shared_ptr<Group> g = m;
    if(m->matches()) {
        std::shared_ptr<Pattern> p = cctki_piraha::compile(g,false,thisg);
        thisg->patterns.put(name,p);
    } else {
        std::ostringstream o;
        o << "Could not compile(" << name << "," << pattern << ")" << std::endl;;
        o << "pos = " << m->pos;
        ERROR(__LINE__,__FILE__,o.str().c_str());
    }
}
}
