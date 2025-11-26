VIVADO ?= vivado
PROJ := $(notdir $(CURDIR))

OUTDIR := out
BIT := $(OUTDIR)/$(PROJ).bit

SOURCES := $(shell find src -type f \( -name '*.v' -o -name '*.sv' \) 2>/dev/null)
XDC := $(wildcard constr/*.xdc)

.PHONY: all help check build sim sim_gui bit clean veryclean

all: build

help:
	@echo "Targets:"
	@echo "  make build	  	  - run Vivado GUI build (uses build.tcl)"
	@echo "  make sim         - run Vivado simulation (batch mode, uses sim.tcl)"
	@echo "  make sim_gui     - run Vivado simulation (GUI mode, uses sim.tcl)"
	@echo "  make bit         - run Vivado batch build (uses bit.tcl)"
	@echo "  make clean       - remove out/ and Vivado work dirs"
	@echo "  make veryclean   - clean + IDE/OS leftovers"
	@echo ""
	@echo "Variables (override if needed):"
	@echo "  TOP=<top_module>    (default: $(TOP))"
	@echo "  PART=<fpga_part>    (default: $(PART))"
	@echo ""
	@echo "Examples:"
	@echo "  make bit"
	@echo "  make bit TOP=counter_top PART=xc7a35ticsg324-1L"

check:
	@command -v $(VIVADO) >/dev/null 2>&1 || { \
	  echo "ERROR: '$(VIVADO)' not found in PATH"; exit 127; }

build: scripts/build.tcl
	$(VIVADO) -mode gui -source scripts/build.tcl &

sim: $(SOURCES) scripts/sim.tcl
	@echo "Run simulation (batch mode)" 
	$(VIVADO) -mode batch -source scripts/sim.tcl &

sim_gui: $(SOURCES) scripts/sim.tcl
	$(VIVADO) -mode gui -source scripts/sim.tcl &

bit: $(BIT) scripts/bit.tcl
$(BIT): $(SOURCES) $(XDC)
	@mkdir -p $(OUTDIR)
	@echo "Run Vivado build (batch mode)"
	$(VIVADO) -mode batch -source scripts/bit.tcl
	@test -f "$(BIT)" || { echo "ERROR: expected bitstream '$(BIT)' not found"; exit 1; }

clean:
	@rm -rf $(OUTDIR) .Xil .cache .runs .sim .gen *.log *.jou *.str

veryclean: clean
	@rm -rf .out .vscode .idea Thumbs.db .DS_Store
