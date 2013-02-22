#include <string.h>
#include "Piraha.hpp"

Matcher::Matcher(smart_ptr<Grammar> g_,const char *pat_,const char *input_,int input_size_) :
    Group(pat_,input_),
    input(input_), g(g_), input_size(input_size_),
    pos(0), max_pos(-1), pat(pat_), expected(), err_pos(-1) {
    inrule = pat_;
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
    err_pos = -1;
    children.clear();
    bool b = p->match(this);
    end_ = pos;
    return b;
}

void Matcher::fail(Bracket *br) {
    for(unsigned int i=0;i<br->ranges.size();i++) {
        fail(br->ranges[i]->lo,br->ranges[i]->hi);
    }
}

void Matcher::fail(char lo,char hi) {
    if(pos == max_pos+1) {
        if(err_pos < pos)
            expected.ranges.clear();
        expected.addRange(lo,hi);
        inrule_max = inrule;
        err_pos = pos;
    }
}

void Matcher::showError() {
	int line = 1;
	int error_pos = -1;
	const int num_previous_lines = 4;
	int start_of_line = 0;
	int start_of_previous_line[num_previous_lines];
	for(int i=0;i<num_previous_lines;i++)
		start_of_previous_line[i] = 0;
	for(int i=0;i<input_size;i++) {
		if(i == max_pos) {
            std::cout << "In rule '" << inrule_max
			    <<  "' Line=" << line << std::endl;
			error_pos = i;
			while(input[i] == '\n'||input[i] == '\r') {
				line++;
				for(int j=1;j<num_previous_lines;j++) {
					start_of_previous_line[j-1] = start_of_previous_line[j];
				}
				start_of_previous_line[num_previous_lines-1] = start_of_line;
				start_of_line = ++i;
			}
			break;
		}
		if(input[i] == '\n') {
			line++;
			for(int j=1;j<num_previous_lines;j++) {
				start_of_previous_line[j-1] = start_of_previous_line[j];
			}
			start_of_previous_line[num_previous_lines-1] = start_of_line;
			start_of_line = i+1;
		}
	}
	for(int i=start_of_previous_line[0];i<input_size;i++) {
		std::cout << input[i];
		if(i > error_pos && input[i] == '\n')
			break;
	}
	for(int i=start_of_line;i<=error_pos;i++)
		std::cout << ' ';
	std::cout << "^" << std::endl;
    std::cout << "Expected one of the following characters: " << expected << std::endl;
}
