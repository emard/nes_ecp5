PROJ=nes
IDCODE ?= 0x21111043 # 12f

all: ${PROJ}.bit

%.json: $(wildcard *.v)
	yosys -q -p "synth_ecp5 -abc9 -json $@" $^

%_out.config: %.json
	nextpnr-ecp5 --json  $< --textcfg $@ --25k --freq 21 --package CABGA381 --lpf ulx3s.lpf

%.bit: %_out.config
	ecppack --freq 19.4 --idcode $(IDCODE) --svf ${PROJ}.svf $< $@

${PROJ}.svf : ${PROJ}.bit

prog: ${PROJ}.bit
	ujprog $<

testbench:  $(filter-out $(wildcard pll.v),$(wildcard *.v)) $(wildcard sim/*.v)
	iverilog -DSIM=1 -o testbench $^ $(shell yosys-config --datdir/ecp5/cells_sim.v)

rom/game%.bin: rom/game%.nes
	rom/nes2bin.py $^ $@

GAMES = $(sort $(wildcard rom/game*.nes))
IMAGES = $(GAMES:.nes=.bin)

rom/games.bin: $(IMAGES)
	cat $^ > $@
	
games_32.hex: rom/games.bin
	hexdump -e '4/1 "%02X" "\n"' $< -v > $@

games_8.hex: rom/games.bin
	hexdump -e '1/1 "%02X" "\n"' $< -v > $@

testbench_vcd: testbench games_8.hex
	vvp -N testbench -fst +vcd

clean:
	rm -f *.svf *.bit *.config *.json


.PHONY: prog clean
