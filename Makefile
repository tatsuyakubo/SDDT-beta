create_project:
	vivado \
	    -mode batch \
	    -source scripts/create_project.tcl \
	    -tclargs \
			--origin_dir ./scripts \
			--project_name vivado

copy_outputs:
	cp vivado/vivado.runs/impl_1/top.bit ./vivado/top_$$(date +%m%d).bit
	cp vivado/vivado.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh ./vivado/top_$$(date +%m%d).hwh

clean:
	rm *.jou
	rm *.log
