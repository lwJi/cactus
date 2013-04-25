# Build the standalone tool
#
BIN ?= .
PIRAHA_HOME ?= .
CXX ?= c++
CC ?= cc
CXXFLAGS ?= -g -O2 -Wall
CCFLAGS ?= -g -O2 -Wall
SRC_NAMES = \
	AutoGrammar.cc Bracket.cc Dot.cc End.cc \
	Grammar.cc Group.cc ILiteral.cc \
	Literal.cc Lookup.cc Matcher.cc Multi.cc \
	Or.cc ReParse.cc Seq.cc smart_ptr.cc Start.cc \
	Boundary.cc NegLookAhead.cc cinterface.cc
SRCS = $(patsubst %.cc,$(PIRAHA_HOME)/%.cc,$(SRC_NAMES))
OBJS = $(patsubst %.cc,$(BIN)/%.o,$(SRC_NAMES))

bin : $(BIN) $(BIN)/generic

$(BIN):
	mkdir -p $(BIN)

$(BIN)/generic : $(PIRAHA_HOME)/libpiraha.a $(PIRAHA_HOME)/Generic.o
	$(CXX) $(CXXFLAGS) -o $(BIN)/generic $(PIRAHA_HOME)/Generic.o $(PIRAHA_HOME)/libpiraha.a

lib : $(PIRAHA_HOME)/libpiraha.a
$(PIRAHA_HOME)/libpiraha.a : $(OBJS)
	ar cr $(PIRAHA_HOME)/libpiraha.a $(OBJS)

EXAMPLE_CC_SRCS = $(PIRAHA_HOME)/example0.c $(PIRAHA_HOME)/example1.c $(PIRAHA_HOME)/example2.c
EXAMPLE_CXX_SRCS = $(PIRAHA_HOME)/example3.cc 
EXAMPLE_OBJS = $(patsubst %.c,%.o,$(EXAMPLE_CC_SRCS)) $(patsubst %.cc,%.o,$(EXAMPLE_CXX_SRCS))
EXAMPLES     = $(patsubst %.c,%  ,$(EXAMPLE_CC_SRCS)) $(patsubst %.cc,%,$(EXAMPLE_CXX_SRCS))
ex : $(EXAMPLES)

all : ex bin

$(PIRAHA_HOME)/example0 : $(PIRAHA_HOME)/example0.o $(PIRAHA_HOME)/libpiraha.a
	$(CXX) $(CXXFLAGS) -o $(PIRAHA_HOME)/example0 example0.o -L $(PIRAHA_HOME) -lpiraha
$(PIRAHA_HOME)/example1 : $(PIRAHA_HOME)/example1.o $(PIRAHA_HOME)/libpiraha.a
	$(CXX) $(CXXFLAGS) -o $(PIRAHA_HOME)/example1 example1.o -L $(PIRAHA_HOME) -lpiraha
$(PIRAHA_HOME)/example2 : $(PIRAHA_HOME)/example2.o $(PIRAHA_HOME)/libpiraha.a
	$(CXX) $(CXXFLAGS) -o $(PIRAHA_HOME)/example2 example2.o -L $(PIRAHA_HOME) -lpiraha
$(PIRAHA_HOME)/example3 : $(PIRAHA_HOME)/example3.o $(PIRAHA_HOME)/libpiraha.a
	$(CXX) $(CXXFLAGS) -o $(PIRAHA_HOME)/example3 example3.o -L $(PIRAHA_HOME) -lpiraha

$(BIN)/%.o : $(PIRAHA_HOME)/%.cc $(PIRAHA_HOME)/Piraha.hpp
	$(CXX) $(CXXFLAGS) -o $(BIN)/$*.o -I $(PIRAHA_HOME) -c $<

$(BIN)/%.o : $(PIRAHA_HOME)/%.c $(PIRAHA_HOME)/Piraha.h
	$(CC) $(CCFLAGS) -o $(BIN)/$*.o -I $(PIRAHA_HOME) -c $<

$(PIRAHA_HOME)/cinterface.o : $(PIRAHA_HOME)/Piraha.h

clean :
	rm -f $(BIN)/generic $(OBJS) $(PIRAHA_HOME)/libpiraha.a $(EXAMPLES) $(EXAMPLE_OBJS)
