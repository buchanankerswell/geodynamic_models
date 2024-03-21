# Logging config
DATE = $(shell date +"%d-%m-%Y")
LOGFILE := $(CURDIR)/log/log-$(DATE)
LOG := 2>&1 | tee -a $(LOGFILE)
# Install scripts
INSTALLDIR = $(CURDIR)/assets/install
# Aspect 
ASPECTINSTALL = $(INSTALLDIR)/aspect-2.5.sh
ASPECTPATH = $(CURDIR)/assets/aspect_2.5
ASPECTCB = $(ASPECTPATH)/deps/aspect/cookbooks
ASPECTPRM ?= $(ASPECTCB)/convection-box/convection-box.prm
# LaMEM
LAMEMPATH = $(INSTALLDIR)/lamem
LAMEMCB = $(CURDIR)/assets/examples/lamem
LAMEMPRM ?= $(LAMEMCB)/sphere.jl
# Global params
NPROC ?= 8
# Cleanup directories
DATAPURGE = log
DATACLEAN = $(ASPECTPATH)

all: $(LOGFILE) $(ASPECTINSTALL)

aspect_model: install_aspect
	@echo "Running aspect model:" $(LOG) && echo "$(ASPECTPRM)" $(LOG)
	@mpirun -np $(NPROC) $(ASPECTPATH)/aspect $(ASPECTPRM) $(LOG)
	@echo "=============================================" $(LOG)

install_aspect: $(LOGFILE) $(ASPECTINSTALL)
	@if [ ! -d "$(ASPECTPATH)" ]; then \
		$(INSTALLDIR)/aspect-2.5.sh $(CURDIR) $(ASPECTPATH) $(LOG); \
	else \
		echo "aspect v2.5 found!" $(LOG); \
	fi
	@echo "=============================================" $(LOG)

lamem_model: $(LOGFILE) instantiate_lamem
	@julia --project=$(LAMEMPATH) $(LAMEMPRM) $(LOG)
	@echo "=============================================" $(LOG)

instantiate_lamem: $(LOGFILE) $(LAMEMPATH) check_julia
	@julia -e "using Pkg; Pkg.activate(\"$(LAMEMPATH)\");  Pkg.instantiate()" $(LOG)
	@echo "=============================================" $(LOG)

check_julia:
	@if command -v julia &> /dev/null; then \
		echo "Found Julia!" $(LOG); \
	else \
		echo "Error: Julia is not installed on this system!" $(LOG); \
		echo "Install Julia with:" $(LOG); \
		echo "'curl -fsSL https://install.julialang.org | sh'" $(LOG); \
	fi

$(LOGFILE):
	@if [ ! -e "$(LOGFILE)" ]; then \
		mkdir -p log; \
		touch $(LOGFILE); \
	fi

purge:
	@rm -rf $(DATAPURGE)

clean: purge
	@rm -rf $(DATACLEAN)

.PHONY: clean purge build_underworld_model2 install_aspect aspect_model all
