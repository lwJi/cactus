# Build the standalone tool
#
BIN ?= .
PIRAHA_HOME ?= .
CXX ?= c++
CXXFLAGS ?= -g -O2
SRC_NAMES = \
	AutoGrammar.cc Bracket.cc Dot.cc End.cc \
	Generic.cc Grammar.cc Group.cc ILiteral.cc \
	Literal.cc Lookup.cc Matcher.cc Multi.cc \
	Or.cc ReParse.cc Seq.cc smart_ptr.cc Start.cc \
	Boundary.cc NegLookAhead.cc
SRCS = $(patsubst %.cc,$(PIRAHA_HOME)/%.cc,$(SRC_NAMES))

$(BIN)/generic : $(SRCS) $(PIRAHA_HOME)/Piraha.hpp $(PIRAHA_HOME)/smart_ptr.hpp
	@echo BUILDING $(BIN)/generic
	mkdir -p $(BIN)
	$(CXX) $(CXXFLAGS) -I $(PIRAHA_HOME) -o $(BIN)/generic $(SRCS)

clean :
	rm -f $(BIN)/generic
