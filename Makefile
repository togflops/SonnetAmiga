HOST=aos3	# pass unix on any unix-like

ASM68K=vasmm68k_mot
ASMPPC=vasmppc_std
LD=vlink
LHA=lha
IRA=ira

IRAPARAM=-M68020
ASM68KPARAM=-m68020up -Fhunk
ASMPPCPARAM=-many -mppc32 -Fhunk    

DISTRIBUTION=sonnet.lha

SONNETLIB_N=sonnetlib
SONNETLIB_LIB=sonnet.library
TOOLS_N=tools
TOOLS_GETINFO=getinfo
TOOLS_GETINFOPPC=getinfo_ppc

export

all : $(SONNETLIB_N) $(TOOLS_N)

$(SONNETLIB_N) :
	$(MAKE) -C $(SONNETLIB_N)

$(TOOLS_N) :
	$(MAKE) -C $(TOOLS_N)

disasm68k :
	$(MAKE) -C $(SONNETLIB_N) disasm68k
	$(MAKE) -C $(TOOLS_N) disasm68k
	
clean :
	$(MAKE) -C $(SONNETLIB_N) clean
	$(MAKE) -C $(TOOLS_N) clean
	$(RM) $(DISTRIBUTION)

distribution :
	$(LHA) a $(DISTRIBUTION) $(SONNETLIB_N)/$(SONNETLIB_LIB) $(TOOLS_N)/$(TOOLS_GETINFO) $(TOOLS_N)/$(TOOLS_GETINFOPPC) README

.PHONY: $(SONNETLIB_N) $(TOOLS_N)

include Makefile.inc.$(HOST)

