#include "Piraha.hpp"
#include <fstream>

void read_file(const char *file,std::string& buf) {
    std::ifstream in;
    in.open(file);
    while(true) {
        int c = in.get();
        if(c < 0)
            break;
        buf += (char)c;
    }
    in.close();
}

int main(int argc,char **argv) {
    if(argc != 3) {
        std::cerr << "usage: generic grammar input" << std::endl;
        return 2;
    }

    std::string grammar_file, input_file;
    read_file(argv[1],grammar_file);
    read_file(argv[2],input_file);

    smart_ptr<Grammar> g = new Grammar();
    compileFile(g,grammar_file.c_str());
    smart_ptr<Matcher> mg = new Matcher (g,g->default_rule.c_str(),input_file.c_str());
    if(mg->matches()) {
        mg->dump();
    } else {
        mg->showError();
    }
    return 0;
}
