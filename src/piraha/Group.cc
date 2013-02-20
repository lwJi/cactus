#include "Piraha.hpp"

void Group::dump(int indent) {
    for(int i=0;i<indent;i++)
        std::cout << ' ';
    std::cout << pattern << ": ";
    if(children.size()==0) {
        for(int i=start_;i<end_;i++)
            std::cout << input[i];
    }
    std::cout << std::endl;
    typedef vector<smart_ptr<Group> >::iterator group_iter;
    for(group_iter gi = children.begin();
            gi != children.end();
            ++gi) {
        (*gi)->dump(indent+2);
    }
}

std::string Group::substring() {
    std::string sub;
    for(int i=start_;i<end_;i++) {
        sub += input[i];
    }
    return sub;
}

std::string Group::getPatternName() {
    return pattern;
}

int Group::line() {
	int line = 1;
	for(int i=0;i<start_;i++) {
		if(input[i] == '\n')
			line++;
	}
	return line;
}
