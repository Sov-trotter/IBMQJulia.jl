#todo variational gate correction stuff :Done
# add methods for h and rz conversions 
# cleanup multiple dispatch
function yaotoqobj(qc::Array{ChainBlock{N}}, device::String; nshots=1024) where N
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
    n_classical_reg = 2 
    nslots=1
    c_label = [["c", i] for i in 0:n_classical_reg-1]
    q_label = [["q", i] for i in 0:n_qubits-1]
    exp_inst = generate_instv2(qc_simpl)
    exp_header = Dict("memory_slots"=>nslots, "n_qubits"=>n_qubits, "clbit_labels"=>c_label, "qubit_labels"=>q_label)
    experiment = Dict("header"=>exp_header, "config"=>Dict(), "instructions"=>exp_inst)
    return experiment    
end

function generate_inst(qc_simpl::ChainBlock)
    inst = []
    for block in subblocks(qc_simpl)
        i = generate_inst(block)
        if block isa ChainBlock
            if i isa Array{Array}                             # for nested chains
                push!(inst, Iterators.flatten(i)...)  #generalize this to loop till we get a Array{Dict} 
            else
                append!(inst, i)
            end
        else
            push!(inst, i)
        end
    end
    return inst
end

function generate_inst(blk::PutBlock{N,M}) where {N,M}
	locs = [blk.locs...]
	generate_instv2(blk.content, locs)
end

function generate_inst(blk::ControlBlock{N,GT,C}) where {N,GT,C}
	generate_instv2(blk.content, blk.locs, blk.ctrl_locs)
end

function generate_inst(blk::ChainBlock, locs::Array) 
    ins = []
    for sub_blk in subblocks(blk)
        push!(ins, generate_instv2(sub_blk, locs))
    end
    return ins
end

# IBMQ Chip only supports ["id", "u1", "u2", "u3", "cx"]
# Conversions implemented for H, RX, RY, RZ 
generate_inst(::HGate, locs) = Dict("name"=>"u2", "qubits"=>locs, "params"=>[0, π]) 
generate_inst(::I2Gate, locs) = Dict("name"=>"id", "qubits"=>locs) 
generate_inst(::TGate, locs) = Dict("name"=>"t", "qubits"=>locs) 
generate_inst(::SWAPGate, locs) = Dict("name"=>"swap", "qubits"=>locs) 
generate_inst(::Measure, locs) = Dict("name"=>"measure", "qubits"=>locs, "memory"=>[0])# memory:  List of memory slots in which to store the measurement results (mustbe the same length as qubits).  

generate_inst(b::ShiftGate, locs, ctrl_locs) = Dict("name"=>"cu1", "qubits"=>[locs..., ctrl_locs...], "params"=>[b.theta])

generate_inst(::XGate, locs::Array) = Dict("name"=>"x", "qubits"=>locs)
generate_inst(::YGate, locs::Array) = Dict("name"=>"y", "qubits"=>locs)
generate_inst(::ZGate, locs::Array) = Dict("name"=>"z", "qubits"=>locs)

generate_inst(::XGate, locs::Tuple, ctrl_locs::Tuple) = Dict("name"=>"cx", "qubits"=>[locs..., ctrl_locs...])
generate_inst(::YGate, locs::Tuple, ctrl_locs::Tuple) = Dict("name"=>"cy", "qubits"=>[locs..., ctrl_locs...])
generate_inst(::ZGate, locs::Tuple, ctrl_locs::Tuple) = Dict("name"=>"cz", "qubits"=>[locs..., ctrl_locs...])

generate_inst(b::RotationGate{1, T, XGate}, locs) where T = Dict("name"=>"u3", "qubits"=>locs, "params"=>[b.theta, -π/2, π/2])
generate_inst(b::RotationGate{1, T, YGate}, locs) where T = Dict("name"=>"u2", "qubits"=>locs, "params"=>[b.theta, 0, 0])
generate_inst(b::RotationGate{1, T, ZGate}, locs) where T = Dict("name"=>"u1", "qubits"=>locs, "params"=>[b.theta])

function basicstyle(blk::AbstractBlock)
	YaoBlocks.Optimise.simplify(blk, rules=[YaoBlocks.Optimise.to_basictypes])
end
