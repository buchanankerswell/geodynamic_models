# Logging config
DATE = $(shell date +"%d-%m-%Y")
LOGFILE := log/log-$(DATE)
LOG := 2>&1 | tee -a $(LOGFILE)
# Directories with build scripts and models 
BUILDDIR = assets/build_scripts
MODELDIR = assets/models
# Build scripts
SHBUILDS = $(BUILDDIR)/aspect-2.5.sh
# Geodynamic models
ASPECT = $(MODELDIR)/aspect_2.5
# Aspect setup
PRM ?= $(ASPECT)/dependencies/aspect/cookbooks/convection-box/convection-box.prm
NPROC ?= 8
# Cleanup directories
DATAPURGE = log
DATACLEAN = $(MODELDIR)

all: $(LOGFILE) $(MODELDIR) $(SHBUILDS)

run_aspect_model: $(ASPECT)
	@echo "Running aspect model:" $(LOG) && echo "$(PRM)" $(LOG)
	@mpirun -np $(NPROC) ./$(ASPECT)/aspect $(PRM) $(LOG)
	@echo "=============================================" $(LOG)

$(ASPECT): $(LOGFILE) $(MODELDIR) $(SHBUILDS)
	@if [ ! -d "$(ASPECT)" ]; then \
		./$(BUILDDIR)/aspect-2.5.sh $(LOG); \
	else \
		echo "aspect v.25 found!" $(LOG); \
	fi
	@echo "=============================================" $(LOG)

$(MODELDIR):
	@if [ ! -d "$(MODELDIR)" ]; then \
		mkdir -p "$(MODELDIR)"; \
	fi
	@echo "=============================================" $(LOG)

$(LOGFILE):
	@if [ ! -e "$(LOGFILE)" ]; then \
		mkdir -p log; \
		touch $(LOGFILE); \
	fi

purge:
	@rm -rf $(DATAPURGE)

clean: purge
	@rm -rf $(DATACLEAN)

.PHONY: clean purge run_aspect_model all
