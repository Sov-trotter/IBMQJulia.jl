#todo :phase gate
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
    n_classical_reg = 2 # figure out this info
    nslots=1
    c_label = [["c", i] for i in 0:n_classical_reg-1]
    q_label = [["q", i] for i in 0:n_qubits-1]
    exp_inst = generate_inst(qc_simpl)
    exp_header = Dict("memory_slots"=>nslots, "n_qubits"=>n_qubits, "clbit_labels"=>c_label, "qubit_labels"=>q_label)
    experiment = Dict("header"=>exp_header, "config"=>Dict(), "instructions"=>exp_inst)
    return experiment    
end

function generate_inst(qc_simpl::ChainBlock)
    inst = []
    for block in subblocks(qc_simpl)
        if block isa Union{PutBlock{N, M, ChainBlock{M}}, ChainBlock{O}} where {N, M, O}
            push!(inst, generate_inst(block)...)
        else
            push!(inst, generate_inst(block))
        end
    end
    return inst
end

function generate_inst(blk::PutBlock)
    gate = blk.content
    if gate isa HGate
        nm = "h"
    elseif gate isa I2Gate
        nm = "id"
    elseif gate isa TGate
        nm = "t"
    elseif gate isa SWAPGate
        nm = "swap"
    elseif gate isa Measure
        nm = "measure"
    end

    if nm == "measure"
        return Dict("name"=>"$(nm)", "qubits"=>[blk.locs...], "memory"=>[0])# memory:  List of memory slots in which to store the measurement results (mustbe the same length as qubits).  
        #todo: generalize "memory" for all cases               
    else    
        return Dict("name"=>"$(nm)", "qubits"=>[blk.locs...]) 
    end
end

function generate_inst(blk::PutBlock{N, M, ChainBlock{M}}) where {N, M}
    data = []
    for gate in blk.content
        super_blk = gate.block
        if super_blk isa ZGate
            nm = "rz"
        elseif super_blk isa YGate
            nm = "ry"
        elseif super_blk isa XGate
            nm = "rx"
        end
        inst = Dict("name"=>"$(nm)", "qubits"=>[blk.locs...], "params"=>[gate.theta])
        push!(data, inst)
    end
    return Tuple(data)
end

function generate_inst(blk::ControlBlock)
    gate = blk.content
    if gate isa XGate
        nm = "cx"
    elseif gate isa YGate
        nm = "cy"
    elseif gate isa ZGate
        nm = "cz"
    elseif gate isa ShiftGate
        nm = "cu1"
        angle = gate.theta  #use Base.propertynames here
    elseif gate isa PhaseGate   #fix this
        nm = "s"
    end
    
    if nm == "cu1" 
        return Dict("name"=>"$(nm)", "qubits"=>[blk.locs..., blk.ctrl_locs...], "params"=>[angle])  
    else  
        return Dict("name"=>"$(nm)", "qubits"=>[blk.locs..., blk.ctrl_locs...])
    end
end

function basicstyle(blk::AbstractBlock)
	YaoBlocks.Optimise.simplify(blk, rules=[YaoBlocks.Optimise.to_basictypes])
end














# memory_slots: Number of classical memory slots used in this job.  Memory slotsare used to record the results of 
# qubit measurements and read out at the end of an experiment. They cannot be used for feedback (those are the registers).