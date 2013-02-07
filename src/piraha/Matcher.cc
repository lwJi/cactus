#include <string.h>
#include "Piraha.hpp"

Matcher::Matcher(smart_ptr<Grammar> g_,const char *pat_,const char *input_,int input_size_) :
    Group(pat_,input_),
    input(input_), g(g_), input_size(input_size_),
    pos(0), max_pos(-1), pat(pat_), expected("") {
	if(input_size < 0)
		input_size=strlen(input);
}

bool Matcher::matches() {
    smart_ptr<Pattern> p = g->patterns.get(pat);
    if(!p.valid()) {
        std::cout << "Grammar does not contain \"" << pat << "\"" << std::endl;
    }
    assert(p.valid());
    pos = 0;
    max_pos = -1;
    children.clear();
    bool b = p->match(this);
    end_ = pos;
    return b;
}

void Matcher::showError() {
	int line = 1;
	int error_pos = -1;
	int start_of_line = 0;
	for(int i=0;i<input_size;i++) {
		if(i == max_pos) {
			std::cout <<  "Line=" << line << std::endl;
			error_pos = i;
			break;
		}
		if(input[i] == '\n') {
			line++;
			start_of_line = i+1;
		}
	}
	for(int i=start_of_line;i<input_size;i++) {
		std::cout << input[i];
		if(input[i] == '\n')
			break;
	}
	for(int i=start_of_line;i<=error_pos;i++)
		std::cout << ' ';
	std::cout << "^" << std::endl;
}
