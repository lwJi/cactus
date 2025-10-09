#include "Piraha.hpp"
#include <stdlib.h>
#include <string.h>

namespace cctki_piraha {

char getChar(std::shared_ptr<Group> gr) {
    if(gr->groupCount()==1) {
        std::string sub = gr->group(0)->substring();
        int n = 0;
        for(unsigned int i=0;i<sub.size();i++) {
            char c = sub[i];
            if(c >= '0' && c <= '9')
                n = n*16+c-'0';
            else if(c >= 'a' && c <= 'f')
                n = n*16+c-'a'+10;
            else if(c >= 'A' && c <= 'F')
                n = n*16+c-'A'+10;
        }
    }
    std::string gs = gr->substring();
    if(gs.size()==2) {
        char c = gs[1];
        if(c == 'n')
            return '\n';
        else if(c == 'r')
            return '\r';
        else if(c == 't')
            return '\t';
        else if(c == 'b')
            return '\b';
        else
            return c;
    } else {
        return gs[0];
    }
}
std::shared_ptr<Multi> mkMulti(std::shared_ptr<Group> g) {
    if(g->groupCount()==0) {
        std::string s = g->substring();
        if("*" == s) {
            return std::make_shared<Multi>(0,max_int);
        } else if("+" == s) {
            return std::make_shared<Multi>(1,max_int);
        } else if("?" == s) {
            return std::make_shared<Multi>(0,1);
        }
    } else if(g->groupCount()==1) {
        int mn = atol(g->group(0)->substring().c_str());
        return std::make_shared<Multi>(mn,mn);
    } else if(g->groupCount()==2) {
        int mn = atol(g->group(0)->substring().c_str());
        if(g->group(1)->groupCount()>0) {
            int mx = atol(g->group(1)->group(0)->substring().c_str());
            return std::make_shared<Multi>(mn,mx);
        } else {
            return std::make_shared<Multi>(mn,max_int);
        }
    }
    g->dump();
    return NULL;
}


void compileFile(std::shared_ptr<Grammar> g,const char *buffer,signed long buffersize) {
	if(buffersize < 0)
		buffersize = strlen(buffer);
	std::shared_ptr<Grammar> grammar = AutoGrammar::fileParserGenerator();
	std::shared_ptr<Matcher> m = std::make_shared<Matcher>(grammar,"file",buffer,buffersize);
	bool b = m->matches();
    if(!b) {
        m->showError();
	    ERROR(__LINE__,__FILE__,"Error compiling grammar");
    }

	for(int i=0;i<m->groupCount();i++) {
		std::shared_ptr<Group> rule = m->group(i);
		std::shared_ptr<Pattern> ptmp = compile(rule->group(1), false, g);
        std::string nm = rule->group(0)->substring();
		g->patterns.put(nm,ptmp);
        g->default_rule = nm;
	}
}

std::shared_ptr<Pattern> compile(std::shared_ptr<Group> g,bool ignCase,std::shared_ptr<Grammar> gram) {
    std::string pn = g->getPatternName();
    if("literal" == pn) {
        char c = getChar(g);
        if(ignCase)
            return std::make_shared<ILiteral>(c);
        else
            return std::make_shared<Literal>(c);
    } else if("pattern" == pn) {
        if(g->groupCount()==0)
            return std::make_shared<Nothing>();
        return compile(g->group(0),ignCase,gram);
    } else if("pelem" == pn) {
        if(g->groupCount()==2) {
            std::shared_ptr<Multi> pm = mkMulti(g->group(1));
            pm->pattern = compile(g->group(0),ignCase,gram);
            return pm;
        }
        return compile(g->group(0),ignCase,gram);
    } else if("pelems" == pn||"pelems_top" == pn||"pelems_next" == pn) {
        std::vector<std::shared_ptr<Pattern> > li;
        for(int i=0;i<g->groupCount();i++) {
            li.push_back(compile(g->group(i),ignCase,gram));
        }
        if(li.size()==1)
            return li[0];
        return std::make_shared<Seq>(li,false,false);
    } else if("group_inside" == pn||"group_top" == pn) {
        if(g->groupCount()==1)
            return compile(g->group(0),ignCase,gram);
        std::vector<std::shared_ptr<Pattern> > li;
        for(int i=0;i<g->groupCount();i++) {
            li.push_back(compile(g->group(i),ignCase,gram));
        }
        auto or_ = std::make_shared<Or>(false,false);
        or_->patterns = li;
        return or_;
    } else if("group" == pn) {
        auto or_ = std::make_shared<Or>(false,false);
        bool ignC = ignCase;
        std::shared_ptr<Group> inside;
        if(g->groupCount()==2) {
            ignC = or_->igcShow = true;
            std::string ps = g->group(0)->getPatternName();
            if(ps == "ign_on") {
                ignC = or_->ignCase = true;
            } else if(ps == "ign_off") {
                ignC = or_->ignCase = false;
            } else if(ps == "neglookahead") {
                return std::make_shared<NegLookAhead>(compile(g->group(1),ignCase,gram));
            } else if(ps == "lookahead") {
                return std::make_shared<LookAhead>(compile(g->group(1),ignCase,gram));
            }
            inside = g->group(1);
        } else {
            inside = g->group(0);
        }
        for(int i=0;i<inside->groupCount();i++) {
            or_->patterns.push_back(compile(inside->group(i),ignC,gram));
        }
        if(or_->igcShow == false && or_->patterns.size()==1)
            return or_->patterns[0];
        return or_;
    } else if("start" == pn) {
        return std::make_shared<Start>();
    } else if("end" == pn) {
        return std::make_shared<End>();
    } else if("boundary" == pn) {
        return std::make_shared<Boundary>();
    } else if("charclass" == pn) {
        auto br = std::make_shared<Bracket>();
        int i=0;
        if(g->groupCount()>0 && g->group(0)->getPatternName() == "neg") {
            i++;
            br->neg = true;
        }
        for(;i < g->groupCount();i++) {
            std::string gn = g->group(i)->getPatternName();
            if("range"==gn) {
                char c0 = getChar(g->group(i)->group(0));
                char c1 = getChar(g->group(i)->group(1));
                br->addRange(c0, c1, ignCase);
            } else {
                char c = getChar(g->group(i));
                br->addRange(c,c, ignCase);
            }
        }
        return br;
    } else if("named" == pn) {
        std::string lookup = g->group(0)->substring();
        if("brk" == lookup)
            return std::make_shared<Break>();
        return std::make_shared<Lookup>(lookup, gram);
    } else if("nothing" == pn) {
        return std::make_shared<Nothing>();
    } else if("s" == pn||"s0" == pn) {
        return std::make_shared<Lookup>("-skipper", gram);
    } else if("dot" == pn) {
        return std::make_shared<Dot>();
    } else if("backref" == pn) {
        return std::make_shared<BackRef>(g->substring()[1]-'0', ignCase);
    }
    return NULL;
}

}
