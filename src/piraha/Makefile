# Build the standalone tool
#
CXX ?= c++
PERL ?= perl
LIB ?= lib
BIN ?= bin
INC ?= include

CXXFLAGS ?= -g -O2 -I . -I ../include -std=c++11 -DSTANDALONE -I $(INC)
SRCS = AutoGrammar.cc Bracket.cc Dot.cc End.cc \
	Generic.cc Grammar.cc Group.cc ILiteral.cc \
	Literal.cc Lookup.cc Matcher.cc Multi.cc \
	Or.cc ReParse.cc Seq.cc Start.cc \
	Boundary.cc NegLookAhead.cc
OBJS = $(SRCS:%.cc=$(LIB)/%.o)

$(LIB)/%.o : %.cc 
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BIN)/generic : $(LIB)/libpiraha.a Piraha.hpp 
	$(CXX) $(CXXFLAGS) -o $(BIN)/generic $(OBJS)

$(LIB)/libpiraha.a : $(OBJS) 
	ar cr $(LIB)/libpiraha.a $(OBJS)

clean :
	rm -f $(OBJS) $(BIN)/generic

Generic.cc : $(INC)/ParGrammar.hh

$(INC)/ParGrammar.hh : pegs/par.peg 
	$(PERL) make.hh.pl $< $@

Call.o: $(INC)/ParGrammar.hh
