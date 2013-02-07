#include <iostream>
#include "Piraha.hpp"

bool Multi::match(Matcher *m) {
    unsigned int save;
    int iter = 0;
    while(true) {
        save = m->pos;
        if(!pattern->match(m))
            break;
        if(save-m->pos == 0)
            return minv <= iter && iter <= maxv;
        iter++;
    }
    m->pos = save;
    return minv <= iter && iter <= maxv;
}
