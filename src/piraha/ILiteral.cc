#include "Piraha.hpp"

ILiteral::ILiteral(char b) : lc(lc_(b)), uc(uc_(b)) {}

bool ILiteral::match(Matcher *m) {
    if(m->pos >= (int)m->input_size )
        return false;
    char c = m->input[m->pos];
    if(c == uc || c == lc) {
        m->max_pos = std::max(m->pos,m->max_pos);
        m->pos++;
        return true;
    } else {
        if(m->pos == m->max_pos+1) {
            m->expected = '[';
            m->expected += lc;
            m->expected += uc;
            m->expected += ']';
        }
        return false;
    }
}
