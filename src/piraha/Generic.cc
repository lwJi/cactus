#include "Piraha.hpp"
#include <fstream>

int main(int argc,char **argv) {
    AutoGrammar a;
    smart_ptr<Grammar> g = a.fileParserGenerator();
    std::ifstream in;

    in.open(argv[1]);
    std::string grammar((std::istreambuf_iterator<char>(in)),
                         std::istreambuf_iterator<char>());
    in.close();

    Grammar *gt = new Grammar();
    smart_ptr<Matcher> mg = new Matcher (g,"file",grammar.c_str());
    std::string last_pattern;
    if(mg->matches()) {
        //std::cout << "Match, grammar compiled" << std::endl;
        for(int i=0;i < mg->groupCount();i++) {
            smart_ptr<Group> rule = mg->group(i);
            last_pattern = rule->group(0)->substring();
            //std::cout << "Compile: " << last_pattern << std::endl;
            gt->compile(last_pattern,rule->group(1));
        }
    } else {
        //std::cout << "Failed, near " << mg->pos << std::endl;
        return 2;
    }

    in.open(argv[2]);
    std::string text((std::istreambuf_iterator<char>(in)),
                      std::istreambuf_iterator<char>());
    in.close();

    //std::cout << "Match rule (" << last_pattern << ") against (" << text << ")" << std::endl;
    smart_ptr<Matcher> mt = new Matcher(gt,last_pattern.c_str(),text.c_str());
    if(mt->matches()) {
        std::cout << "Match, text matches" << std::endl;
    } else {
        int line = 1, i0 = 0;
        for(int i=0;i<=mt->max_pos;i++) {
            if(text[i] == '\n') {
                line++;
                i0 = i+1;
            }
        }
        std::cout << "Failed, near line " << line << std::endl;
        for(unsigned int i=i0;i<text.size();i++) {
            std::cout << text[i];
            if(text[i] == '\n')
                break;
        }
        for(int i=i0;i<=mt->max_pos;i++) {
            std::cout << ' ';
        }
        std::cout << "^" << std::endl;
        for(int i=i0;i<=mt->max_pos;i++) {
            std::cout << ' ';
        }
        std::cout << mt->expected << " <- expected" << std::endl;
    }
    return 0;
}
