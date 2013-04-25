#include <stdio.h>
#include <string.h>
#include "Piraha.h"
#include <stdlib.h>
#include <assert.h>

// Print out the parse tree.
void print_parse_tree(pir_group_t *g,int indent) {
    int i;
    char buf[50];
    for(i=0;i<indent;i++)
        printf(" ");
    pir_get_str(g,buf);
    printf("%s(%d,%d)=%s\n",g->pir_name,g->pir_start,g->pir_end,buf);
    for(i=0;i<g->pir_ngroups;i++) {
        pir_group_t ch;
        pir_get_group(g,i,&ch);
        print_parse_tree(&ch,indent+2);
    }
}

// Evaluate the expression by recursively
// descending through the parse tree.
int eval(pir_group_t *gr) {
    if(strcmp(gr->pir_name,"num")==0) {
        char buf[10];
        pir_get_str(gr,buf);
        return atoi(buf);
    } else if(strcmp(gr->pir_name,"value")==0) {
        pir_group_t ch;
        pir_get_group(gr,0,&ch);
        return eval(&ch);
    } else if(strcmp(gr->pir_name,"expr")==0) {
        // Process +'s and -'s
        pir_group_t ch;
        pir_get_group(gr,0,&ch);
        int val = eval(&ch);
        int i;
        for(i=1;i < gr->pir_ngroups;i+=2) {
            char op[2];
            pir_get_group(gr,i,&ch);
            pir_get_str(&ch,op);
            pir_get_group(gr,i+1,&ch);
            int val2 = eval(&ch);
            if(op[0] == '+')
                val += val2;
            else
                val -= val2;
        }
        return val;
    } else if(strcmp(gr->pir_name,"add")==0) {
        // Process *'s and /'s
        pir_group_t ch;
        pir_get_group(gr,0,&ch);
        int val = eval(&ch);
        int i;
        for(i=1;i < gr->pir_ngroups;i+=2) {
            char op[2];
            pir_get_group(gr,i,&ch);
            pir_get_str(&ch,op);
            pir_get_group(gr,i+1,&ch);
            int val2 = eval(&ch);
            if(op[0] == '*')
                val *= val2;
            else
                val /= val2;
        }
        return val;
    } else {
        printf("Not implemented %s\n",gr->pir_name);
        assert(0);
        return -1;
    }
}

int main() {
    // Allocate a grammar
    pir_grammar_t *gram = pir_alloc_grammar();

    // Compile the rules individually
    pir_compile(gram,"num","[0-9]+");
    pir_compile(gram,"value","{num}|\\({expr}\\)");
    pir_compile(gram,"mulop","[*/]");
    pir_compile(gram,"add","{value}({mulop}{value})*");
    pir_compile(gram,"addop","[+-]");
    pir_compile(gram,"expr","{add}({addop}{add})*");

    // Attempt a match
    // The matcher holds the parse tree in memory.
    pir_matcher_t *matcher = pir_alloc_matcher(gram,"expr","3+4*(5-1*2)");
    pir_group_t group;
    if(pir_matches(matcher,&group)) {
        printf("Match succeeded!\n");

        print_parse_tree(&group,0);

        printf("answer = %d\n",eval(&group));

        pir_free_matcher(matcher);
    }

    // Free the space used by the Grammar
    pir_free_grammar(gram);
    return 0;
}
