#include <string.h>
#include "Piraha.hpp"
#include <sstream>

using namespace piraha;

Matcher::Matcher(Grammar *g_,const char *pat_,const char *input_,int input_size_) :
    Group(pat_,input_),
    input(input_), g(g_), input_size(input_size_),
    pos(0), max_pos(-1), pat(pat_), expected_(), err_pos(-1) {
    inrule = pat_;
	if(input_size < 0)
		input_size=strlen(input);
}

bool Matcher::matches() {
    smart_ptr<Pattern> p = g->patterns.get(pat);
    if(!p.valid()) {
        std::cout << "Grammar does not contain \"" << pat << "\"" << std::endl;
        std::cout << g->patterns << std::endl;
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
            expected_.ranges.clear();
        expected_.addRange(lo,hi);
        inrule_max = inrule;
        err_pos = pos;
    }
}

smart_ptr<Near> Matcher::near() {
    smart_ptr<Near> near = new Near();

	int line = 1;
	int error_pos = -1;
	const int num_previous_lines = 4;
	int start_of_line = 0;
	int start_of_previous_line[num_previous_lines];
	for(int i=0;i<num_previous_lines;i++)
		start_of_previous_line[i] = 0;
	for(int i=0;i<input_size;i++) {
		if(i == max_pos) {
			error_pos = i;
			int column = i - start_of_previous_line[0]+1;
            near->column = column;
		    //std::cout << "In rule '" << inrule_max
			    //<<  "' Line=" << line << ", Column=" << column << std::endl;
            near->rule = inrule_max;
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
    bool eol = false;
	for(int i=start_of_previous_line[0];i<input_size;i++) {
		std::cout << input[i];
		if(i > error_pos && input[i] == '\n') {
            eol = true;
			break;
        }
	}
    near->eol = eol;
    //if(!eol) std::cout << std::endl;
	//for(int i=start_of_line;i<=error_pos;i++)
		//std::cout << ' ';
	//std::cout << "^" << std::endl;
    //std::cout << "Expected one of the following characters: " << expected_ << ", found " << input[err_pos] <<  std::endl;
    near->pos = err_pos;
    near->startOfLine = start_of_line;
    near->lineNum = line;
    std::ostringstream msg;
    msg << expected_;
    near->expected = msg.str();
    return near;
}

void Matcher::showError() {
    smart_ptr<Near> near = this->Matcher::near();
	std::cout << "In rule '" << near->rule
	    <<  "' Line=" << near->lineNum
        << ", Column=" << near->column << std::endl;
    if(!near->eol) std::cout << std::endl;
	for(int i=near->startOfLine;i<=near->pos;i++)
		std::cout << ' ';
	std::cout << "^" << std::endl;
    std::cout << "Expected one of the following characters: "
        << near->expected << ", found "
        << near->text[near->pos] <<  std::endl;
}

smart_ptr<Group> Matcher::result() {
    smart_ptr<Group> g = new Group(*this);
    return g;
}
