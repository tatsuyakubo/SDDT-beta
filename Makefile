all: software

create_vivado_project:
	vivado \
	    -mode batch \
	    -source scripts/vivado1.tcl \
	    -tclargs \
			--origin_dir ./scripts \
			--project_name vivado2

copy_vivado_outputs:
	mkdir -p ./bin
	if [ -f vivado1/vivado1.runs/impl_1/ps_interface_wrapper.bit ]; then cp vivado1/vivado1.runs/impl_1/ps_interface_wrapper.bit ./bin/top_$(shell date +%m%d)_1.bit; fi
	if [ -f vivado1/vivado1.gen/sources_1/bd/ps_interface/hw_handoff/ps_interface.hwh ]; then cp vivado1/vivado1.gen/sources_1/bd/ps_interface/hw_handoff/ps_interface.hwh ./bin/top_$(shell date +%m%d)_1.hwh; fi
	if [ -f vivado2/vivado2.runs/impl_1/top.bit ]; then cp vivado2/vivado2.runs/impl_1/top.bit ./bin/top_$(shell date +%m%d)_2.bit; fi
	if [ -f vivado2/vivado2.gen/sources_1/bd/ps_interface/hw_handoff/ps_interface.hwh ]; then cp vivado2/vivado2.gen/sources_1/bd/ps_interface/hw_handoff/ps_interface.hwh ./bin/top_$(shell date +%m%d)_2.hwh; fi
	if [ -f vivado3/vivado3.runs/impl_1/top.bit ]; then cp vivado3/vivado3.runs/impl_1/top.bit ./bin/top_$(shell date +%m%d)_3.bit; fi
	if [ -f vivado3/vivado3.gen/sources_1/bd/ps_interface/hw_handoff/ps_interface.hwh ]; then cp vivado3/vivado3.gen/sources_1/bd/ps_interface/hw_handoff/ps_interface.hwh ./bin/top_$(shell date +%m%d)_3.hwh; fi

build_kernel_module:
	make -C src/kernel_module wc_driver

software:
	make -C src/software

clean:
	make -C src/software clean
	rm -rf ./bin
	rm -f *.jou
	rm -f *.log
