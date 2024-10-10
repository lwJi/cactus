# make (defaults to ThornGuide.pdf)
# make ThornGuide.tex
# make ThornGuide.pdf
# make THORNS="CactusWave/IDScalarWave,CactusWave/WaveToyF77" ARRANGEMENTS="CactusBase,CactusPUGHIO"


# backwards compatibility for VERBOSE=yes (SILENT=no)
ifeq ($(shell echo $(strip $(SILENT)) | tr '[:upper:]' '[:lower:]'),no)
VERBOSE = yes
endif
# Make quietly unless told not to
ifneq ($(shell echo $(strip $(VERBOSE)) | tr '[:upper:]' '[:lower:]'),yes)
.SILENT:
endif

ifeq ($(strip $(CCTK_HOME)), )
   CCTK_HOME:=$(shell pwd | sed 's,^/cygdrive/\(.\)/,\1:/,' | sed 's,^//\(.\)/,\1:/,' | sed 's/\/doc\/ThornGuide.*//' )
endif
DOCBUILDDIR:=$(shell pwd)

ARRANGEMENTS_DIR=$(CCTK_HOME)/arrangements

ifeq ($(strip $(THORNLIST)), )
   THORNLIST=allthorns.th
endif

ifeq ($(strip $(TOCDEPTH)), )
   TOCDEPTH=0
endif

ifeq ($(strip $(PERL)), )
   PERL=/usr/bin/perl
endif

ifeq ($(strip $(MASTER_FILE)), )
   MASTER_FILE=ThornGuide
endif

IMAGE_FILE=$(CCTK_HOME)/doc/UsersGuide/bincactus2.pdf
IMAGE_FILE_HTML=$(CCTK_HOME)/doc/UsersGuide/bincactus2.ps

-include make.thornlist

.PHONY: default HTML

default : $(MASTER_FILE).pdf
HTML: $(MASTER_FILE).html

$(MASTER_FILE).pdf: $(MASTER_FILE).tex
	@echo "  LaTeXing $<...."
	# Fall through any latex errors so as to print sensible error message
	-pdflatex --interaction errorstopmode $< < /dev/null 2>&1 > LOG_LATEX_FULL_MSGS
	-pdflatex $< < /dev/null 2>&1 > LOG_LATEX_FULL_MSGS
	-pdflatex $< < /dev/null 2>&1 | tee LOG_LATEX_FULL_MSGS | grep -v Underfull | grep -v Overfull | grep -v OT1 > LOG_LATEX_MSGS
	if test -e "$@"; then                                    \
	   if grep "^\! " "LOG_LATEX_FULL_MSGS" | grep -v "destination with the same identifier" | grep -v "You have requested package" ; then            \
	     echo "  Problem in $<.  See $(DOCBUILDDIR)/LOG_LATEX_* .";  \
	     exit 1;                                             \
	   elif grep "^LaTeX Warning:" "LOG_LATEX_FULL_MSGS" | grep -v "destination with the same identifier" | grep -v "You have requested package" ; then         \
	     echo "  Warnings in $<.  See $(DOCBUILDDIR)/LOG_LATEX_* ."; \
	     exit 0;                                             \
	   fi;                                                    \
	else                                                     \
	   echo "  Cannot find $@, an error must have occured. See $(DOCBUILDDIR)/LOG_LATEX_* ."; \
	fi

$(MASTER_FILE).html: $(MASTER_FILE).tex
	# Convert figures to postscript
	$(CCTK_HOME)/lib/sbin/ConvertFigures $(CCTK_HOME)/arrangements
	@echo "  HTML-LaTeXing $<...."
	# Fall through any latex errors so as to print sensible error message
	-$(HTLATEX) $< $(HTLATEXFLAGS) < /dev/null 2>&1 | tee LOG_LATEX_FULL_MSGS | grep -v Underfull | grep -v Overfull | grep -v OT1 > LOG_LATEX_MSGS ; \
	if test -e "$(MASTER_FILE).html"; then                                    \
	   if grep "^\! " "LOG_LATEX_FULL_MSGS" | grep -v "destination with the same identifier" | grep -v "You have requested package" ; then            \
	     echo "  Problem in $<.  See $(DOCBUILDDIR)/LOG_LATEX_* .";  \
	     exit 1;                                             \
	   elif grep "^LaTeX Warning:" "LOG_LATEX_FULL_MSGS" | grep -v "destination with the same identifier" | grep -v "You have requested package" ; then         \
	     echo "  Warnings in $<.  See $(DOCBUILDDIR)/LOG_LATEX_* ."; \
	   fi ; \
	   : use relative paths for figures and other files in HTML && \
	   sed -e "s+$(CCTK_HOME)/arrangements/++g" <$(MASTER_FILE).html > $(MASTER_FILE).html.tmp && \
           mv $(MASTER_FILE).html.tmp $(MASTER_FILE).html &&       \
	   mkdir -p $(MASTER_FILE) &&      \
	   $(PERL) -e 'use File::Path qw{ mkpath };use File::Basename qw{ dirname }; while(<>){chomp;if(m!^File: $(CCTK_HOME)/arrangements/(.*)!){mkpath("$(MASTER_FILE)/".dirname($$1));rename("$(CCTK_HOME)/arrangements/$$1", "$(MASTER_FILE)/$$1");}}' $(MASTER_FILE).lg && \
	   $(PERL) -ne 'chomp;m!^File: ([^/]*)! and rename($$1, "$(MASTER_FILE)/$$1")' $(MASTER_FILE).lg ; \
	else                                                     \
	   echo "  Cannot find $@, an error must have occured. See $(DOCBUILDDIR)/LOG_LATEX_* ."; \
	fi

$(MASTER_FILE).tex:  $(foreach thorn, $(THORN_DEPENDENCIES), $(thorn)/param.ccl $(thorn)/interface.ccl $(thorn)/schedule.ccl) $(THORNLIST)
	@echo "  Gathering documentation from thorn ccl files"
	@echo "    Processing...."
	@echo "       param.ccl...."
	$(PERL) -s $(CCTK_HOME)/lib/sbin/ParamLatex.pl -cctk_home=$(CCTK_HOME) -directory=$(ARRANGEMENTS_DIR) -thornlist=$(THORNLIST) -outdir=./ -section -grouping=bythorn -sort=scope > LOG_PARAMLATEX_MSGS 2>&1
	@echo "       interface.ccl...."
	$(PERL) -s $(CCTK_HOME)/lib/sbin/InterLatex.pl -cctk_home=$(CCTK_HOME) -directory=$(ARRANGEMENTS_DIR) -thornlist=$(THORNLIST) -outdir=./ -section -grouping=bythorn > LOG_INTERLATEX_MSGS 2>&1
	@echo "       schedule.ccl...."
	$(PERL) -s $(CCTK_HOME)/lib/sbin/SchedLatex.pl -cctk_home=$(CCTK_HOME) -directory=$(ARRANGEMENTS_DIR) -thornlist=$(THORNLIST) -outdir=./ -section > LOG_SCHEDLATEX_MSGS 2>&1
	@echo "  Creating $@...."
	$(PERL) -s $(CCTK_HOME)/lib/sbin/ThornGuide.pl -cctk_home=$(CCTK_HOME) -directory=$(ARRANGEMENTS_DIR) -thornlist=$(THORNLIST) -outdir=./ -outfile=$(MASTER_FILE).tex -tocdepth=$(TOCDEPTH) > LOG_THORNGUIDE_MSGS 2>&1
	if test -e $(IMAGE_FILE) && test ! -e "bincactus2.pdf"; then \
	   cp $(IMAGE_FILE) .;                                       \
	fi
	if test -e $(IMAGE_FILE_HTML) && test ! -e "bincactus2.ps"; then \
	   cp $(IMAGE_FILE_HTML) .;                                       \
	fi

make.thornlist: $(THORNLIST) 
	THORN_DEPENDENCIES=`$(PERL) -s $(CCTK_HOME)/lib/sbin/ThornList.pl -arrangements_dir=$(ARRANGEMENTS_DIR) -thornlist=$(THORNLIST)`

$(THORNLIST):
	@echo "  Creating $@...."
	$(PERL) -s $(CCTK_HOME)/lib/sbin/ThornList.pl -arrangements_dir=$(ARRANGEMENTS_DIR) -thorns=$(THORNS) -arrangements=$(ARRANGEMENTS)> $@ 
