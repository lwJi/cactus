#include <stdio.h>
#include <string.h>
#include "Piraha.h"
#include <stdlib.h>
#include <assert.h>

int main() {
    // Allocate a grammar
    pir_grammar_t *gram = pir_alloc_grammar();

    // Compile the rules individually
    pir_compile(gram,"num","[0-9]+");
    pir_compile(gram,"expr","range=\\[{num}:{num}\\]");

    // Attempt a match
    // The matcher holds the parse tree in memory.
    pir_group_t group,ch;
    const char *input = "range=[10:150]";
    const char *pattern_name = 0; // use default
    pir_matcher_t *matcher = pir_alloc_matcher(gram,pattern_name,input);
    if(pir_matches(matcher,&group)) {
        printf("Match succeeded!\n");
        char buf[10];
        int v1,v2;

        pir_get_group(&group,0,&ch);
        pir_get_str(&ch,buf);
        v1 = atoi(buf);

        pir_get_group(&group,1,&ch);
        pir_get_str(&ch,buf);
        v2 = atoi(buf);

        printf("v1=%d,v2=%d\n",v1,v2);
    } else {
        char expected[20];
        int pos = pir_error(matcher,expected);
        printf("fail at pos=%d: found=(%c), expected=%s\n",pos,input[pos],expected);
    }
    pir_free_matcher(matcher);

    // Free the space used by the Grammar
    pir_free_grammar(gram);
    return 0;
}
