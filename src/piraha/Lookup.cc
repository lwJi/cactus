#include "Piraha.hpp"

Lookup::Lookup(std::string name_,smart_ptr<Grammar> g) : gram(g), name(name_), capture(true) {
    if(name[0] == '-') {
        capture = false;
        name = name.substr(1);
    }
}

bool Lookup::match(Matcher *m) {
    smart_ptr<Pattern> p = gram->patterns.get(name);
    if(!p.valid()) std::cout << "Lookup of pattern [" << name << "] failed. Jmap = " << gram->patterns << std::endl;
    assert(p.valid());
    vector<smart_ptr<Group> > chSave = m->children;
    m->children.clear();
    int s = m->pos;
    std::string save_name = m->inrule;
    m->inrule += "::";
    m->inrule += name;
    bool b = p->match(m);
    m->inrule = save_name;
    int e = m->pos;
    if(b) {
        smart_ptr<Group> g = new Group(name,m->input,s,e,m->children);
        if(capture)
            chSave.push_back(g);
    }
    m->children = chSave;
    return b;
}
