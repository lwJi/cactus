#include "Piraha.hpp"

bool Range::match(Matcher *m) {
    if(m->pos - m->input_size >= 0)
        return false;
    char c = m->input[m->pos];
    if(lo <= c && c <= hi) {
        return true;
    } else {
        return false;
    }
}

Bracket::Bracket(bool b) : neg(b), ranges() {}

Bracket *Bracket::addRange(char lo,char hi) {
    ranges.push_back(new Range(lo,hi));
    return this;
};

Bracket *Bracket::addRange(char lo,char hi,bool ign) {
    if(ign) {
        char lolc = lc_(lo);
        char hilc = lc_(hi);
        char louc = uc_(lo);
        char hiuc = uc_(hi);
        if(lolc == louc && hilc == hiuc) {
            ranges.push_back(new Range(lo,hi));
        } else {
            ranges.push_back(new Range(lolc,hilc));
            ranges.push_back(new Range(louc,hiuc));
        }
    } else {
        ranges.push_back(new Range(lo,hi));
    }
    return this;
};

static void fail(Bracket *b,Matcher *m) {
    typedef std::vector<smart_ptr<Range> >::iterator range_iter;
    if(m->pos == m->max_pos+1) {
        m->expected = '[';
        if(b->neg) m->expected += '^';
        for(range_iter r = b->ranges.begin();r != b->ranges.end(); ++r) {
            if((*r)->lo == (*r)->hi) {
                m->expected += (*r)->lo;
            } else {
                m->expected += (*r)->lo;
                m->expected += '-';
                m->expected += (*r)->hi;
            }
        }
        m->expected += ']';
    }
}

bool Bracket::match(Matcher *m) {
    if(m->pos >= (int)m->input_size)
        return false;
    typedef std::vector<smart_ptr<Range> >::iterator range_iter;
    for(range_iter r = ranges.begin();r != ranges.end(); ++r) {
        if((*r)->match(m)) {
            if(neg) {
                fail(this,m);
                return false;
            } else {
                m->max_pos = std::max(m->pos,m->max_pos);
                m->pos++;
                return true;
            }
        }
    }
    if(!neg) {
        fail(this,m);
        return false;
    } else {
        m->pos++;
        m->max_pos = std::max(m->pos,m->max_pos);
        return true;
    }
}
