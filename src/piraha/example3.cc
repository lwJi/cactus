#include <iostream>
#include <stdlib.h>
#include "Piraha.hpp"

using namespace piraha;

int main() {
    // Allocate a grammar
    smart_ptr<Grammar> gram = new Grammar();

    // Compile the rules individually
    gram->compile("num","[0-9]+");
    gram->compile("expr","range=\\[{num}:{num}\\]");

    // Attempt a match
    // The matcher holds the parse tree in memory.
    std::string input = "range=[10:150]";
    smart_ptr<Matcher> matcher = gram->matcher(input.c_str());
    if(matcher->matches()) {
        std::cout << "Match succeeded!" << std::endl;
        int v1,v2;

        smart_ptr<Group> group = matcher->result();
        smart_ptr<Group> ch = group->group(0);
        std::string s = ch->substring();
        v1 = atoi(s.c_str());

        ch = group->group(1);
        s = ch->substring();
        v2 = atoi(s.c_str());

        std::cout << "v1=" << v1 << ",v2=" << v2 << std::endl;
    } else {
        smart_ptr<Near> near = matcher->near();
        int pos = near->pos;
        std::string expected = near->expected;
        std::cerr << "fail at pos=" << pos
            << ": found='" << input[pos]
            << "', expected=" << expected << std::endl;
    }
    return 0;
}

