# Logging config
DATE = $(shell date +"%d-%m-%Y")
LOGFILE := log/log-$(DATE)
LOG := 2>&1 | tee -a $(LOGFILE)
# Directories with build scripts and models 
BUILDDIR = assets/build_scripts
MODELDIR = assets/models
# Build scripts
SHBUILDS = $(BUILDDIR)/aspect-2.5.sh
# Cleanup directories
DATAPURGE = log
DATACLEAN = $(MODELDIR)

all: $(LOGFILE) $(MODELDIR) $(SHBUILDS)

aspect: $(LOGFILE) $(MODELDIR) $(SHBUILDS)
	@./$(BUILDDIR)/aspect-2.5.sh $(LOG)
	@echo "=============================================" $(LOG)

$(LOGFILE):
	@if [ ! -e "$(LOGFILE)" ]; then \
		mkdir -p log; \
		touch $(LOGFILE); \
	fi

$(MODELDIR):
	@if [ ! -d "$(MODELDIR)" ]; then \
		mkdir -p "$(MODELDIR)"; \
		echo "Directory '$(MODELDIR)' created successfully." $(LOGFILE); \
	else \
		echo "Directory '$(MODELDIR)' already exists." $(LOGFILE); \
	fi
	@echo "=============================================" $(LOG)

purge:
	@rm -rf $(DATAPURGE)

clean: purge
	@rm -rf $(DATACLEAN)

.PHONY: clean purge aspect all
