#ifndef PIRAHA_HPP
#define PIRAHA_HPP

#include <climits>
#include <cstring>
#include <initializer_list>
#include <iostream>
#include <map>
#include <memory>
#include <string>
#include <vector>

#ifdef STANDALONE
#define ERROR(LINE, FILE, MSG) {std::cerr << FILE << ":" << LINE << " " << MSG << std::endl; exit(2); }
#else
#include <cctk.h>
#define ERROR(LINE, FILE, MSG) CCTK_ERROR(LINE, FILE, "Cactus", MSG)
#endif

#ifdef NDEBUG
#define ASSERT(X) /**/
#else
#define ASSERT(X) if(!(X)) ERROR(__LINE__, __FILE__, #X)
#endif

namespace cctki_piraha {

const int max_int = INT_MAX-1;

inline char uc_(char a) {
    if(a >= 'a' && a <= 'z')
        return a + 'A' - 'a';
    else
        return a;
}

inline char lc_(char a) {
    if(a >= 'A' && a <= 'Z')
        return a + 'a' - 'A';
    else
        return a;
}

class Group {
public:
    std::string pattern;
    const char *input;
    int start_,end_;
    std::shared_ptr<std::vector<std::shared_ptr<Group> > > children;

    Group(const char *p,const char *value)
        : pattern(p), input(value), start_(0), end_(strlen(value)),
        children(std::make_shared<std::vector<std::shared_ptr<Group> > >()) {
        }
    Group(std::string p,const char *input_)
        : pattern(p), input(input_), start_(0), end_(0), children(std::make_shared<std::vector<std::shared_ptr<Group> > >()) {}
    Group(std::string p,const char *input_,int s,int e,
        std::shared_ptr<std::vector<std::shared_ptr<Group> > > ch)
        : pattern(p), input(input_), start_(s), end_(e), children(ch) {}

    virtual ~Group() {}

    int start() { return start_; }
    int end() { return end_; }
    int childCount(), line();
    std::string getPatternName();
    std::string substring();
    std::shared_ptr<Group> child(int i);
    void dump(std::ostream& o=std::cout);
    void dump(int n,std::ostream& o,int indent=0);
    void dumpPerl(std::ostream&o=std::cout);
    void dumpPerl(std::ostream&o,int indent);
    void dumpPython(std::ostream&o=std::cout);
    void dumpPython(std::ostream&o,int indent);
    int groupCount() { return children->size(); }
    std::shared_ptr<Group> group(int i) { return (*children)[i]; }
    std::shared_ptr<Group> group(const char *nm,int ix=0) {
    	for(unsigned int i=0;i<children->size();i++) {
    		if((*children)[i]->getPatternName() == nm) {
    			if(ix == 0) {
    				return (*children)[i];
    			}
    			ix--;
    		}
    	}
    	std::shared_ptr<Group> ret;
    	return ret;
    }
    int showError(std::ostream& o);
};

class Grammar;

class Matcher;

class Pattern {
public:
    virtual bool match(std::shared_ptr<Matcher> m)=0;
    Pattern() {}
    virtual ~Pattern() {}
    virtual std::string fmt() { return "blank"; }
    virtual void insert(std::ostream& o) { o << "{?}"; }
};

inline std::ostream& operator<<(std::ostream& o,Pattern& p) {
    p.insert(o);
    return o;
}

class JMap {
    std::map<std::string,std::shared_ptr<Pattern> > m;
public:
    JMap() : m() {}
    std::shared_ptr<Pattern> get(std::string key) {
        typedef std::map<std::string,std::shared_ptr<Pattern> >::iterator mit;
        mit it = m.find(key);
        mit me = m.end();
        if(it == me) {
            return NULL;
        }
        std::shared_ptr<Pattern> res = m[key];
        ASSERT(res);
        return res;
    }
    void put(std::string key,std::shared_ptr<Pattern> p) {
        ASSERT(p);
        if(m.find(key) != m.end()) {
            std::cerr << "Duplicate key given to Grammar: '" << key << "'" << std::endl;
            abort();
        }
        m[key] = p;
    }
    void put(std::string key,Pattern *p) {
        put(key, std::shared_ptr<Pattern>(p));
    }
    friend std::ostream& operator<<(std::ostream&,JMap&);
};
inline std::ostream& operator<<(std::ostream& o,JMap& jmap) {
    typedef std::map<std::string,std::shared_ptr<Pattern> >::iterator mit;
    mit mb = jmap.m.begin();
    mit me = jmap.m.end();
    o << "{";
	for(mit i = mb; i != me;++i) {
		o << "[" << i->first << "]";
	}
	o << "}";
	return o;
}


class Grammar {
public:
    Grammar() {}
    virtual ~Grammar() {}
    JMap patterns;
    std::string default_rule;
};

class Seq : public Pattern {
    std::vector<std::shared_ptr<Pattern> > patterns;
public:
    Seq(std::initializer_list<Pattern *> patterns);
    Seq(std::vector<std::shared_ptr<Pattern> > patterns,bool ign,bool show);
    virtual ~Seq() {}
    bool match(std::shared_ptr<Matcher> m);
    virtual void insert(std::ostream& o) {
        for(unsigned int i=0;i<patterns.size();i++)
            o << *patterns[i];
    }
};

class Or : public Pattern {
public:
    std::vector<std::shared_ptr<Pattern> > patterns;
    bool ignCase, igcShow;
    Or(bool ign,bool show) : ignCase(ign), igcShow(show) {}
    Or(std::initializer_list<Pattern *> patterns);
    virtual ~Or() {}
    bool match(std::shared_ptr<Matcher> m);
    virtual void insert(std::ostream& o) {
        o << "(";
        for(unsigned int i=0;i<patterns.size();i++) {
            if(i > 0) o << "|";
            o << *patterns[i];
        }
        o << ")";
    }
};

class Literal : public Pattern {
public:
    const char c;
    Literal(char b) : c(b) {}
    bool match(std::shared_ptr<Matcher> m);
    std::string fmt() {
        std::string s = "literal(";
        s += c;
        s += ")";
        return s;
    }
    virtual void insert(std::ostream& o) {
        if(c == '\n')
            o << "\\n";
        else if(c == '\r')
            o << "\\r";
        else if(c == '\t')
            o << "\\t";
        else if(c == '\b')
            o << "\\b";
        else if(c >= 'a' && c <= 'z')
            o << c;
        else if(c >= 'A' && c <= 'Z')
            o << c;
        else if(c >= '0' && c <= '9')
            o << c;
        else
            o << "\\" << c;
    }
};

class ILiteral : public Pattern {
public:
    const char lc,uc;
    ILiteral(char b);
    bool match(std::shared_ptr<Matcher> m);
    std::string fmt() {
        std::string s = "Iliteral(";
        s += lc;
        s += ",";
        s += uc;
        s += ")";
        return s;
    }
    virtual void insert(std::ostream& o) {
        char c = lc;
        if(lc != uc)
            o << "[" << lc << uc << "]";
        else if(c == '\n')
            o << "\\n";
        else if(c == '\r')
            o << "\\r";
        else if(c == '\t')
            o << "\\t";
        else if(c == '\b')
            o << "\\b";
        else if(c >= 'a' && c <= 'z')
            o << c;
        else if(c >= 'A' && c <= 'Z')
            o << c;
        else if(c >= '0' && c <= '9')
            o << c;
        else
            o << "\\" << c;
    }
};

class Lookup : public Pattern {
    std::shared_ptr<Grammar> gram;
    std::string name;
    bool capture;
public:
    Lookup(std::string s,std::shared_ptr<Grammar> g);
    virtual ~Lookup() {}
    bool match(std::shared_ptr<Matcher> m);
    std::string fmt() {
        return "Literal:"+name;
    }
    virtual void insert(std::ostream& o) {
        o << "{" << name << "}";
    }
};

class Nothing : public Pattern {
public:
    Nothing() {}
    bool match(std::shared_ptr<Matcher> m) { return true; }
};

class Start : public Pattern {
public:
    Start() {}
    bool match(std::shared_ptr<Matcher> m);
    virtual void insert(std::ostream& o) { o << "^"; }
};

class End : public Pattern {
public:
    End() {}
    bool match(std::shared_ptr<Matcher> m);
    virtual void insert(std::ostream& o) { o << "$"; }
};

class Dot : public Pattern {
public:
    Dot() {}
    bool match(std::shared_ptr<Matcher> m);
    virtual void insert(std::ostream& o) { o << "."; }
};

class Multi : public Pattern {
    const int minv,maxv;
public:
    std::shared_ptr<Pattern> pattern;
    Multi(int min_,int max_) : minv(min_), maxv(max_), pattern(NULL) {}
    Multi(Pattern* p,int min_,int max_) : minv(min_), maxv(max_), pattern(std::shared_ptr<Pattern>(p)) {}
    virtual ~Multi() {}
    bool match(std::shared_ptr<Matcher> m);
    virtual void insert(std::ostream& o) {
        o << *pattern << "{" << minv << "," << maxv << "}";
    }
};

class Range : public Pattern {
public:
    char lo,hi;
    bool match(std::shared_ptr<Matcher> m);
    Range(char lo_,char hi_) : lo(lo_), hi(hi_) {}
};

  class Bracket : public Pattern {
public:
    bool neg;
    std::vector<std::shared_ptr<Range> > ranges;
    Bracket() : neg(false) {}
    virtual ~Bracket() {}
    Bracket(bool b);
    Bracket* addRange(char lo,char hi);
    Bracket* addRange(char lo,char hi,bool ign);
    bool match(std::shared_ptr<Matcher> m);
    virtual void insert(std::ostream& o);
};

class NegLookAhead : public Pattern {
public:
    std::shared_ptr<Pattern> pattern;
    NegLookAhead(std::shared_ptr<Pattern> p) : pattern(p) {}
    virtual ~NegLookAhead() {}
    bool match(std::shared_ptr<Matcher> m);
};

class LookAhead : public Pattern {
public:
    std::shared_ptr<Pattern> pattern;
    LookAhead(std::shared_ptr<Pattern> p) : pattern(p) {}
    virtual ~LookAhead() {}
    bool match(std::shared_ptr<Matcher> m) { ERROR(__LINE__,__FILE__,"Not implemented"); }//TODO: Fill in
};

class Boundary : public Pattern {
    virtual bool match(std::shared_ptr<Matcher> m);
};

class Break : public Pattern {
    virtual bool match(std::shared_ptr<Matcher> m) { ERROR(__LINE__,__FILE__,"Not implemented"); }//TODO: Fill in
};

class BackRef : public Pattern {
public:
    int index;
    bool ignCase;
    BackRef(int in,bool ign) : index(in), ignCase(ign) {}
    virtual bool match(std::shared_ptr<Matcher> m) { ERROR(__LINE__,__FILE__,"Not implemented"); }//TODO: Fill in
};

class AutoGrammar {
public:
    static std::shared_ptr<Grammar> reparserGenerator();
    static std::shared_ptr<Grammar> fileParserGenerator();
};

class Matcher : public Group, public std::enable_shared_from_this<Matcher> {
public:
    Matcher(std::shared_ptr<Grammar> g,const char *pat_,const char *input_,int input_size=-1);
    virtual ~Matcher() {}

    //std::map<std::string,std::vector<smar_ptr<Group> > > packrat;
    const char *input;
    std::shared_ptr<Grammar> g;
    int input_size;
    int pos;
    int max_pos;
    int match_to;
    const char *pat;
    bool matches();
    bool matchesTo(int mt);
    Bracket expected;
    int showError(std::ostream& out);
    int showError();
    std::string inrule;
    std::string inrule_max;
    int err_pos;
    void fail(Bracket *ex);
    void fail(char lo,char hi);
    void fail(char lo);
    char foundChar() { return input[max_pos+1]; }
};

extern std::shared_ptr<Grammar> pegGrammar;
extern std::shared_ptr<Pattern> compile(std::shared_ptr<Group> g,bool ignCase,std::shared_ptr<Grammar> gram);
extern void compileFile(std::shared_ptr<Grammar> g,const char *buffer,signed long buffersize=-1);
void compile(std::shared_ptr<Grammar> thisg,std::string name,std::string pattern);
void compile(std::shared_ptr<Grammar> thisg,std::string name,std::shared_ptr<Group> pattern);
void insertc(std::ostream& o,char c);

}

#endif
