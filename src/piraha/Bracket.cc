#include "Piraha.hpp"

typedef vector<smart_ptr<Range> >::iterator range_iter;

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
	bool done = false;
	while(!done) {
		done = true;
	    for(range_iter ri = ranges.begin();ri != ranges.end(); ++ri) {
			smart_ptr<Range> r = *ri;
			if(hi < r->lo || r->hi < lo) {
				// no intersection
				continue;
			} else {
				lo = std::min(lo,r->lo);
				hi = std::max(hi,r->hi);
				ranges.erase(ri);
				done = false;
				break;
			}
		}
	}
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
    typedef vector<smart_ptr<Range> >::iterator range_iter;
    Bracket bex;
    if(m->pos == m->max_pos+1) {
        for(range_iter r = b->ranges.begin();r != b->ranges.end(); ++r) {
        	bex.addRange((*r)->lo,(*r)->hi);
        }
        m->fail(&bex);
    }
}

bool Bracket::match(Matcher *m) {
    if(m->pos >= (int)m->input_size)
        return false;
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

std::ostream& operator<<(std::ostream& o,Bracket& b) {
    for(range_iter r = b.ranges.begin();r != b.ranges.end(); ++r) {
    	char lo = (*r)->lo, hi = (*r)->hi;
    	if(lo == hi) {
    		if(lo == '-') {
    			o << "\\-";
            } else if(lo == '\n') {
                o << "\\n";
            } else if(lo == '\r') {
                o << "\\r";
            } else if(lo == '\t') {
                o << "\\t";
    		} else {
    			o << lo;
    		}
    	} else {
    		o << lo << '-' << hi;
    	}
    }
    return o;
}
