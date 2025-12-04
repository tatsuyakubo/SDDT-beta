create_vivado_project:
	vivado \
	    -mode batch \
	    -source scripts/create_vivado_project.tcl \
	    -tclargs \
			--origin_dir ./scripts \
			--project_name vivado

copy_vivado_outputs:
	mkdir -p ./build
	cp vivado/vivado.runs/impl_1/top.bit ./build/top_$$(date +%m%d).bit
	cp vivado/vivado.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh ./build/top_$$(date +%m%d).hwh

build_kernel_module:
	make -C src/kernel_module wc_driver

clean:
	rm -rf ./build
	rm -f *.jou
	rm -f *.log
