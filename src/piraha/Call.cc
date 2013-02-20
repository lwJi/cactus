#include <iostream>
#include <string.h>
#include "Piraha.hpp"
#include <stdlib.h>
#include <sstream>
#include "cctk_Parameter.h"
#include <map>
#include <math.h>

#define VAR(X) " " #X "=" << X

extern "C" int CCTK_ParameterFilename(int len, char *filename);

std::map<std::string,std::map<std::string,std::string> > values;
typedef std::map<std::string,std::map<std::string,std::string> >::iterator th_iter;
typedef std::map<std::string,std::string>::iterator nm_iter;

// If the value was already defined in this parameter file, look
// it up in the map. Otherwise, get it from Cactus.
bool find_val(std::string thorn,std::string name,std::string& ret) {
	th_iter th = values.find(thorn);
	if(th != values.end()) {
		nm_iter nm = th->second.find(name);
		if(nm != th->second.end()) {
			ret = nm->second;
			return true;
		}
	}
	const cParamData *data = CCTK_ParameterData(name.c_str(),thorn.c_str());
	if(data == NULL)
		return false;
	ret = data->defval;
	return true;
}

bool lookup_var(smart_ptr<Group> gr,std::string& res) {
	if(gr->group(0)->getPatternName() == "env") {
		const char *env = getenv(gr->group(0)->group(0)->substring().c_str());
		if(env != NULL) {
			res = env;
			return true;
		}
	} else if(gr->group(0)->substring() == "parfile") {
		char path[500];
		CCTK_ParameterFilename(500, path);
		char *value = strrchr (path, '/');
		if (value == NULL) {
			value = path;
		} else {
			value++;
		}
		/* skip the parameter file extension */
		if (strcmp (value + strlen (value) - 4, ".par") == 0)
		{
			value[strlen (value) - 4] = '\0';
		}
		res = value;
		return true;
	} else if(gr->group(0)->substring() == "pi") {
		std::ostringstream ostr;
		ostr << (4.0*atan2(1,1)) << std::flush;
		res = ostr.str();
		return true;
	}
	return false;
}

// Converts a value to a string
void meval(smart_ptr<Group> gr,std::string& val) {
	val.clear();
	if(gr->getPatternName() == "value" || gr->getPatternName() == "paren") {
		meval(gr->group(0),val);
	} else if(gr->getPatternName() == "quot") {
		smart_ptr<Group> inquot = gr->group(0);
		val = inquot->substring();
		int last = 0;
		std::string nw;
		for(int i=0;i < inquot->groupCount();i++) {
			smart_ptr<Group> vr = inquot->group(i);
			std::string sub;
			if(lookup_var(vr,sub)) {
				int start = vr->start() - inquot->start();
				nw += val.substr(last,start-last);
				nw += sub;
				last = vr->end() - inquot->start();
			}
		}
		if(last < val.size())
			nw += val.substr(last,val.size()-last);
		val = nw;
	} else if(gr->getPatternName() == "par") {
		std::string thorn = gr->group(0)->substring();
		std::string name = gr->group(1)->substring();

		bool found = find_val(thorn,name,val);
		if(found) {
			;
		} else {
			val += thorn;
			val += "::";
			val += name;
		}
	} else if(gr->getPatternName() == "name") {
		val += gr->substring();
	} else if(gr->getPatternName() == "num") {
		val += gr->substring();
	} else if(gr->getPatternName() == "var") {
		lookup_var(gr,val);
	} else if(gr->getPatternName() == "mexpr") {
		if(gr->groupCount()==1) {
			meval(gr->group(0),val);
			return;
		}
		std::string val2;
		meval(gr->group(0),val2);
		double v2 = atof(val2.c_str());
		for(int i=1;i < gr->groupCount();i += 2) {
			std::string val3;
			meval(gr->group(i+1),val3);
			double v3 = atof(val3.c_str());
			if(gr->group(i)->substring() == "*") {
				v2 *= v3;
			} else {
				v2 /= v3;
			}
//			std::cout << "MEXPR: " << v2 << gr->group(i)->substring() << v3 << std::endl;
		}
		std::ostringstream ostr;
		ostr << v2 << std::flush;
		val = ostr.str();
	} else if(gr->getPatternName() == "aexpr") {
		if(gr->groupCount()==1) {
			meval(gr->group(0),val);
			return;
		}
		std::string val2;
		meval(gr->group(0),val2);
		double v2 = atof(val2.c_str());
		for(int i=1;i < gr->groupCount();i += 2) {
			std::string val3;
			meval(gr->group(i+1),val3);
			double v3 = atof(val3.c_str());
			if(gr->group(i)->substring() == "+") {
				v2 += v3;
			} else {
				v2 -= v3;
			}
//			std::cout << "AEXPR: " << v2 << gr->group(i)->substring() << v3 << std::endl;
		}
		std::ostringstream ostr;
		ostr << v2 << std::flush;
		val = ostr.str();
	} else if(gr->getPatternName() == "func") {
		std::string func_name = gr->group(0)->substring();
		std::string arg;
		meval(gr->group(1),arg);
		std::stringstream ostr;
		if(func_name == "sin") {
			ostr << sin(atof(arg.c_str()));
		} else if(func_name == "cos") {
			ostr << cos(atof(arg.c_str()));
		} else if(func_name == "sqrt") {
			ostr << sqrt(atof(arg.c_str()));
		} else if(func_name == "tan") {
			ostr << tan(atof(arg.c_str()));
		} else if(func_name == "log") {
			ostr << log(atof(arg.c_str()));
		} else if(func_name == "exp") {
			ostr << exp(atof(arg.c_str()));
		}
		ostr << std::flush;
		val = ostr.str();
	} else {
		std::cout << "Not handled[" << gr->getPatternName() << "]" << std::endl;
		abort();
	}
}

extern "C" int PirahaParser(const char *buffer,unsigned long buffersize,int (*set_function)(const char *, const char *, int)) {
	const char *par_file_src =
			"skipper = ([ \\t\\r\\n]|\\#.*)*\n"

			"# Note that / occurs in some par files. It is my\n"
			"# feeling that this should require quote marks.\n"

			"name = [@a-zA-Z_][@/a-zA-Z0-9_-]*\n"
			"inquot = ({var}|\\\\.|[^\\\\\"])*\n"
			"quot = \"{inquot}\"\n"
			"num = [-+]?([0-9]+(\\.[0-9]*|)|\\.[0-9]+)(e[+-][0-9]+|)\n"
			"env = ENV\\{{name}\\}\n"
			"var = \\$({env}|{name}|\\{{name}\\})\n"

			"mulop = [*/]\n"
			"mexpr = {value}( {mulop} {value})*\n"
			"addop = [+-]\n"
			"aexpr = {mexpr}( {addop} {mexpr})*\n"
			"paren = \\( {aexpr} \\)\n"
			"par = {name} :: {name}\n"
			"func = {name} \\( {aexpr} \\)\n"
			"array = \\[ {aexpr}( , {aexpr})* \\]\n"

			"value = {func}|{paren}|{num}|{quot}|{par}|{name}|{var}\n"

			"int = [0-9]+\n"
			"index = \\[ {int} \\]\n"
			"active = (?i:ActiveThorns)\n"
			"set = ({active}|{par}( {index}|)) = ({array}|{aexpr})\n"
			"file = ( !DESC {quot}|)( ({set} )*)$\n";

	smart_ptr<Grammar> g = new Grammar();
	compileFile(g,par_file_src,strlen(par_file_src));

	std::string active;
    smart_ptr<Matcher> m2 = new Matcher(g,"file",buffer,buffersize);
    if(m2->matches()) {
    	int line = -1;
    	for(int i=0;i<m2->groupCount();i++) {
    		smart_ptr<Group> gr = m2->group(i);
    		if(gr->group(0)->getPatternName() == "active") {
    			std::string val;
    			meval(gr->group(1),val);
    			active += val;
    			active += ' ';
    			line = gr->line();
    		}
    	}
    	set_function("ActiveThorns",active.c_str(),line);
    	for(int i=0;i<m2->groupCount();i++) {
    		smart_ptr<Group> gr = m2->group(i);
    		if(gr->getPatternName() != "set")
    			continue;
    		smart_ptr<Group> par = gr->group("par");
    		if(par.valid()) {
    			// add value->quot->inquot
    			std::string key;
    			std::string thorn = par->group("name",0)->substring();
    			std::string name  = par->group("name",1)->substring();
    			key += thorn;
    			key += "::";
    			key += name;

    			smart_ptr<Group> index = gr->group("index");
    			if(index.valid()) {
    				key += '[';
    				key += index->group(0)->substring();
    				key += ']';
    			}

    			std::string val;
    			smart_ptr<Group> aexpr = gr->group("aexpr");
    			if(aexpr.valid()) {
    				meval(aexpr,val);
    				values[thorn][key] = val;
    				set_function(
    						strdup(key.c_str()),
    						strdup(val.c_str()),
    						gr->group(0)->line());
    			} else {
    				smart_ptr<Group> arr = gr->group("array");
    				for(int i=0;i<arr->groupCount();i++) {
    					aexpr = arr->group(i);
    					std::ostringstream keyi;
    					keyi << key << '[' << (i+1) << ']';
    					meval(aexpr,val);
        				values[thorn][keyi.str()] = val;
        				set_function(
        						strdup(keyi.str().c_str()),
        						strdup(val.c_str()),
        						aexpr->line());
    				}
    			}
    		}
    	}
    } else {
    	std::cout << "ERROR IN PARAMETER FILE: ";
    	m2->showError();
    	return 1;
    }
    return 0;
}
