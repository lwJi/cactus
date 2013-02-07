#include "Piraha.hpp"

bool End::match(Matcher *m) {
    return m->pos == (int)m->input_size;
}
