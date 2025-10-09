#include "Piraha.hpp"

using namespace cctki_piraha;

Lookup::Lookup(std::string name_,std::shared_ptr<Grammar> g) : gram(g), name(name_), capture(true) {
    if(name[0] == '-') {
        capture = false;
        name = name.substr(1);
    }
}

bool Lookup::match(std::shared_ptr<Matcher> m) {
    std::shared_ptr<Pattern> p = gram->patterns.get(name);
    if(!p) std::cout << "Lookup of pattern [" << name << "] failed. Jmap = " << gram->patterns << std::endl;
    ASSERT(p);
    std::shared_ptr<std::vector<std::shared_ptr<Group> > > chSave = m->children;
    m->children = std::make_shared<std::vector<std::shared_ptr<Group> > >();
    int s = m->pos;
    std::string save_name = m->inrule;
    m->inrule += "::";
    m->inrule += name;
    bool b = p->match(m);
    m->inrule = save_name;
    int e = m->pos;
    if(b) {
        /*
        if(capture) {
            std::cout << "Matched: {" << name << "}={";
            for(int i=s;i<e;i++)
                insertc(std::cout,m->input[i]);
            std::cout << "}" << std::endl;
        }
        */
        std::shared_ptr<Group> g = std::make_shared<Group>(name,m->input,s,e,m->children);
        if(capture)
            chSave->push_back(g);
    }
    m->children = chSave;
    return b;
}
