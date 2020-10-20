#todo variational gate correction stuff
# add methods for h and rz conversions 
# cleanup multiple dispatch
function yaotoqobjv2(qc::Array{ChainBlock{N}}, device::String; nshots=1024) where N
    nslots = 1
    main_header = Dict("description"=>"Set of Experiments 1", "backend_name" => "$(device)")
    main_config = Dict("shots"=>nshots, "memory_slots"=>nslots, "init_qubits"=> true)
    experiments = collect(generate_experiment(i) for i in qc)
    data = Dict("qobj_id" => "foo", "schema_version"=>"1.0.0", "type"=>"QASM", "header"=>main_header, "config"=>main_config, "experiments"=>experiments)
    Qobj(data)
end

function generate_experiment(qc::ChainBlock)
    qc_simpl = basicstyle(qc)
    n_qubits = nqubits(qc_simpl)
    n_classical_reg = 2 # figure out this info
    nslots=1
    c_label = [["c", i] for i in 0:n_classical_reg-1]
    q_label = [["q", i] for i in 0:n_qubits-1]
    exp_inst = generate_instv2(qc_simpl)
    exp_header = Dict("memory_slots"=>nslots, "n_qubits"=>n_qubits, "clbit_labels"=>c_label, "qubit_labels"=>q_label)
    experiment = Dict("header"=>exp_header, "config"=>Dict(), "instructions"=>exp_inst)
    return experiment    
end

function generate_instv2(qc_simpl::ChainBlock)
    inst = []
    for block in subblocks(qc_simpl)
        # push!(inst, generate_instv2(block))
        if block isa ChainBlock
            append!(inst, generate_instv2(block))
        else
            push!(inst, generate_instv2(block))
        end
    end
    return inst
end

function generate_instv2(blk::PutBlock{N,M}) where {N,M}
	locs = [blk.locs...]
	generate_instv2(blk.content, locs)
end

function generate_instv2(blk::ControlBlock{N,GT,C}) where {N,GT,C}
	generate_instv2(blk.content, blk.locs, blk.ctrl_locs)
end

generate_instv2(::HGate, locs) = Dict("name"=>"h", "qubits"=>locs) 
generate_instv2(::I2Gate, locs) = Dict("name"=>"id", "qubits"=>locs) 
generate_instv2(::TGate, locs) = Dict("name"=>"t", "qubits"=>locs) 
generate_instv2(::SWAPGate, locs) = Dict("name"=>"swap", "qubits"=>locs) 
generate_instv2(::Measure, locs) = Dict("name"=>"measure", "qubits"=>locs, "memory"=>[0])# memory:  List of memory slots in which to store the measurement results (mustbe the same length as qubits).  

generate_instv2(b::ShiftGate, locs, ctrl_locs) = Dict("name"=>"cu1", "qubits"=>[locs..., ctrl_locs...], "params"=>[b.theta])

generate_instv2(::XGate, locs::Array) = Dict("name"=>"x", "qubits"=>locs)
generate_instv2(::YGate, locs::Array) = Dict("name"=>"y", "qubits"=>locs)
generate_instv2(::ZGate, locs::Array) = Dict("name"=>"z", "qubits"=>locs)

generate_instv2(::XGate, locs::Tuple, ctrl_locs::Tuple) = Dict("name"=>"cx", "qubits"=>[locs..., ctrl_locs...])
generate_instv2(::YGate, locs::Tuple, ctrl_locs::Tuple) = Dict("name"=>"cy", "qubits"=>[locs..., ctrl_locs...])
generate_instv2(::ZGate, locs::Tuple, ctrl_locs::Tuple) = Dict("name"=>"cz", "qubits"=>[locs..., ctrl_locs...])

generate_instv2(b::RotationGate{1, T, XGate}, locs) where T = Dict("name"=>"rx", "qubits"=>locs, "params"=>[b.theta])
generate_instv2(b::RotationGate{1, T, YGate}, locs) where T = Dict("name"=>"ry", "qubits"=>locs, "params"=>[b.theta])
generate_instv2(b::RotationGate{1, T, ZGate}, locs) where T = Dict("name"=>"rz", "qubits"=>locs, "params"=>[b.theta])

function basicstyle(blk::AbstractBlock)
	YaoBlocks.Optimise.simplify(blk, rules=[YaoBlocks.Optimise.to_basictypes])
end

# generate_instv2(PhaseGate)
