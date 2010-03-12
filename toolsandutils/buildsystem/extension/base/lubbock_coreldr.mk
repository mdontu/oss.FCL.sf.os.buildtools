# Copyright (c) 2006-2009 Nokia Corporation and/or its subsidiary(-ies).
# All rights reserved.
# This component and the accompanying materials are made available
# under the terms of "Eclipse Public License v1.0"
# which accompanies this distribution, and is available
# at the URL "http://www.eclipse.org/legal/epl-v10.html".
#
# Initial Contributors:
# Nokia Corporation - initial contribution.
#
# Contributors:
#
# Description:
# Code execute address also set in the linker file
# 
#

# To guarantee there is a slash at the end of EPOCROOT in case there is not.
# This is needed to ensure compatibility with SBSv1. 
TMPROOT:=$(subst \,/,$(EPOCROOT))
EPOCROOT:=$(patsubst %/,%,$(TMPROOT))/

include $(EPOCROOT)epoc32/tools/shell/$(notdir $(basename $(SHELL))).mk


#Set the directories
GENSRCDIR := $(EXTENSION_ROOT)/../e32utils/nandboot/coreldr
SPECSRCDIR := $(EXTENSION_ROOT)/nandboot/coreldr
VARIANTINC := $(EXTENSION_ROOT)/inc
DRIVERDIR := $(VARIANTINC)
EPOCINCDIR = $(EPOCROOT)epoc32/include/lubbock/nand
GENINC1 := $(EPOCROOT)epoc32/include
GENINC2 := $(EPOCROOT)epoc32/include/lubbock/nand
GENDRIVERINC := $(EPOCROOT)epoc32/include/drivers
GENINCPATH:= $(GENSRCDIR) $(SPECSRCDIR) $(VARIANTINC) $(GENINC1) $(GENDRIVERINC)
ASMINCPATH := $(GENINC2)

# Build directory = EPOCBLD
BUILDLOC = $(EPOCBLD)$(call sbsadd,/$(PLATFORM_PATH)/$(CFG_PATH))

# Set the target name
TARGETDIR := $(EPOCROOT)epoc32/release/$(PLATFORM_PATH)
TARGET = $(TARGETDIR)/lubbock_coreldr.bin
TMPTARGET = $(BUILDLOC)/coreldr.tmp

#Rules
vpath %.s . $(SPECSRCDIR) $(SRCDIR)
vpath %.inc . $(SPECSRCDIR) $(VARIANTINC) $(EPOCINCDIR)
vpath %.ginc . $(BUILDLOC)

INCLUDES := nand.inc
DRIVERINCLUDES := nand_fbr_offset.h

VHEADERS := nanddevice.h 
BUILTINCLUDES := nanddevice.inc

ASMSOURCE := coreldrasm.s
GENCPPSOURCE := coreldr.cpp inflate.cpp 
HEADERS := inflate.h coreldr.h
SPECHEADERS := nand_plat.h

#Execution address (top 1M of Lubbock RAM)
LINKBASE = 0xA3F00000



ARMASM_OUT := $(shell armasm 2>&1)
ARMASM_OUT_4 := $(word 4,$(ARMASM_OUT))
# Use GCC toolchain if no other is available
TOOLVER := GCC
RVCTSTR := $(strip $(findstring RVCT, $(ARMASM_OUT_4)))
ifeq "$(RVCTSTR)" "RVCT"
        TOOLVER := RVCT
        OP := --
        OB := o
endif 

#Arm RVCT tools
ifeq "$(TOOLVER)" "RVCT"
        ASM_MACROS += USE_CXSF
        ASM := armasm
        LINK := armlink
        FROMELF := fromelf
        CPP := armcc

        OBJEXT := o
        INCEXT := inc

        ARMCCFLAGS := --arm -c -Otime --cpp

        ARMCCFLAGS := $(ARMCCFLAGS) $(foreach dir,$(GENINCPATH),$(join -I, $(dir)))

        ARMCCFLAGS := $(ARMCCFLAGS) -DEKA2

        ARMCCFLAGS := $(ARMCCFLAGS) --preinclude $(EPOCROOT)epoc32/include/rvct/rvct.h


ifeq "$(CFG)" "UDEB"
        ARMCCFLAGS := $(ARMCCFLAGS) -D_DEBUG
endif
        
        ASM_MACRO_CMD := $(foreach macro,$(ASM_MACROS),$(OP)predefine "$(macro) SETL {TRUE}")
        AFLAGS := -g $(OP)keep $(ASM_MACRO_CMD) -I$(BUILDLOC) -I$(ASMINCPATH)
        LFLAGS := $(OP)entry BootEntry $(OP)ro-base $(LINKBASE) $(OP)FIRST BootEntry $(OP)map	
        SYMOPT := $(OP)symdefs
        ASMTYP := ARMASM
        LINKFILE :=

define do_compile
                $(CPP) $(ARMCCFLAGS) $< -o $@
endef
define do_h2inc
                perl $(EPOCROOT)epoc32/tools/h2inc.pl $< $@ ARMASM
endef
define do_asm
                $(ASM) $(AFLAGS) -$(OB) $@ $(OP)LIST $(join $(basename $@),.lst) $<
endef
define do_link
                $(LINK) $(LFLAGS) -$(OB) $@ $(FULLOBJECTS)
endef
define do_strip
                $(FROMELF) $(OP)bin $(OP)output $@ $<
endef
endif


#GCC build options
ifeq "$(TOOLVER)" "GCC"
        ASM := as
        AFLAGS := -mapcs-32 -R -n -I$(BUILDLOC)

        LINKFLAGS = -n --section-alignment 4 --file-alignment 2 -no-whole-archive
        GCCFLAGS=-march=armv4 -nostdinc -pipe -c -Wall -Wno-ctor-dtor-privacy -Wno-unknown-pragmas
        GCCFLAGS := $(GCCFLAGS) $(foreach dir,$(GENINCPATH),$(join -I, $(dir)))
        GCCDEFS = -D__SYMBIAN32__ -D__GCC32__ -D__EPOC32__ -D__MARM__ -D__MARM_ARM4__ -DEKA2
ifeq "$(CFG)" "UDEB"
        GCC = gcc -x c++ -g -O2 $(GCCFLAGS) -D_DEBUG -D_UNICODE $(GCCDEFS)
        else
        GCC = gcc -x c++ -s -fomit-frame-pointer -O2 $(GCCFLAGS) -DNDEBUG -D_UNICODE $(GCCDEFS)
endif

        LINKFILE = $(SPECSRCDIR)/coreldr.lnk
        OBJEXT := o
        INCEXT := ginc

        PROCESS_INCLUDES := 1
define do_compile
                $(GCC) -o $@ $<
endef
define do_h2inc
                perl $(EPOCROOT)epoc32/tools/h2inc.pl $< $@ AS
                perl $(EPOCROOT)epoc32/tools/armasm2as.pl $@ $(join $(basename $@),.ginc)
endef 
define do_includes
                perl $(EPOCROOT)epoc32/tools/armasm2as.pl $< $@
endef
define do_asm
                perl $(EPOCROOT)epoc32/tools/armasm2as.pl $< $(join $(basename $@),.s)
                $(AS) $(AFLAGS) -o $@ $(join $(basename $@),.s)
endef
define do_strip
                strip -O binary -o "$(TARGET)" "$(TMPTARGET)"
                $(ERASE) $(call slash2generic,"$(TMPTARGET)") 
                echo Built $(TARGET)
endef
define do_link
                ld -o "$(TMPTARGET)"  --start $(FULLOBJECTS) --script=$(LINKFILE)
endef
endif


#CPP source processing
FULLCPPSOURCE := $(addprefix $(GENSRCDIR)/,$(GENCPPSOURCE))

#Header processing
FULLHEADERS := $(addprefix $(GENSRCDIR)/,$(HEADERS))
FULLSPECHEADERS := $(addprefix $(VARIANTINC)/,$(SPECHEADERS))

FULLVHEADERS := $(addprefix $(GENDRIVERINC)/,$(VHEADERS)) 
FULLBUILTINCLUDES := $(addprefix $(BUILDLOC)/,$(BUILTINCLUDES))
$(FULLBUILTINCLUDES) : $(FULLVHEADERS)
	$(do_h2inc)


#object names
GENCPPOBJECTS := $(foreach f,$(GENCPPSOURCE),$(basename $(f)).$(OBJEXT))
FULLGENCPPOBJECTS := $(addprefix $(BUILDLOC)/,$(GENCPPOBJECTS)) 

ASMOBJECTS := $(foreach f,$(ASMSOURCE),$(basename $(f)).$(OBJEXT))
FULLASMOBJECTS := $(addprefix $(BUILDLOC)/,$(ASMOBJECTS))

FULLOBJECTS := $(FULLASMOBJECTS) $(FULLGENCPPOBJECTS)

ifdef PROCESS_INCLUDES

GCCSRC := $(addprefix $(BUILDLOC)/,$(SRC))

#Creation of headers
FULLINCLUDES := $(foreach f,$(INCLUDES),$(basename $(f)).$(INCEXT))
FULLINCLUDES := $(addprefix $(BUILDLOC)/,$(FULLINCLUDES))

FULLDRIVERINCLUDES := $(foreach f,$(DRIVERINCLUDES),$(basename $(f)).$(INCEXT))
FULLDRIVERINCLUDES := $(addprefix $(BUILDLOC)/,$(FULLDRIVERINCLUDES))

$(FULLINCLUDES) : $(BUILDLOC)/%.$(INCEXT) : %.inc $(call pipe,$(BUILDLOC))
	$(do_includes)

$(FULLDRIVERINCLUDES) : $(BUILDLOC)/%.$(INCEXT) : %.inc $(call pipe,$(BUILDLOC))
	$(do_includes)

else
FULLINCLUDES:= $(addprefix $(SPECSRCDIR)/,$(INCLUDES))
FULLDRIVERINCLUDES:= $(addprefix $(DRIVERDIR)/,$(DRIVERINCLUDES))

#Arm RVCT specifics here

endif


#Link 
$(TMPTARGET) : $(FULLOBJECTS)
	$(do_link)

#strip
$(TARGET) : $(TMPTARGET)
	$(do_strip)

#CPP objects
$(FULLGENCPPOBJECTS) : $(BUILDLOC)/%.$(OBJEXT) : $(GENSRCDIR)/%.cpp $(FULLHEADERS) $(FULLSPECHEADERS)
	$(do_compile)


#Asm objects
$(FULLASMOBJECTS) : $(BUILDLOC)/%.$(OBJEXT) : $(SPECSRCDIR)/$(ASMSOURCE) $(FULLINCLUDES) $(FULLBUILTINCLUDES) $(FULLDRIVERINCLUDES)
	$(do_asm)

# make the work directories
$(TARGETDIR) :
	@$(call ifnotexistd,"$(TARGETDIR)")

$(BUILDLOC) :
	@$(call ifnotexistd,"$(BUILDLOC)")



MAKMAKE :
	echo Nothing to do

FREEZE :
	echo Nothing to do

LIB :
	echo Nothing to do

CLEANLIB :
	echo Nothing to do

RESOURCE :
	echo Nothing to do

FINAL :
	echo Nothing to do

ifneq "$(PLATFORM)" "GCCXML"
BLD SAVESPACE : $(TARGETDIR) $(BUILDLOC) $(TARGET)

RELEASABLES :
	@echo "$(TARGET)"

CLEAN :
	-$(ERASE) $(call slash2generic,"$(TARGET)") 
	-$(ERASE) $(call slash2generic,"$(BUILDLOC)/*.*") 
#	-$(ERASE) "$(TARGET)"
#	-$(ERASE) "$(BUILDLOC)/*.*"

else

BLD SAVESPACE :
	echo Nothing to do

RELEASABLES :

CLEAN :
	echo Nothing to do
endif

