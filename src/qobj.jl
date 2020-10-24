export generate_inst, inst2qbir
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
    n_qubits = nqubits(qc_simpl)
    n_classical_reg = 2 
    nslots=1
    c_label = [["c", i] for i in 0:n_classical_reg-1]
    q_label = [["q", i] for i in 0:n_qubits-1]
    exp_inst = generate_inst(qc_simpl)
    exp_header = Dict("memory_slots"=>nslots, "n_qubits"=>n_qubits, "clbit_labels"=>c_label, "qubit_labels"=>q_label)
    experiment = Dict("header"=>exp_header, "config"=>Dict(), "instructions"=>exp_inst)
    return experiment    
end

function generate_inst(qc_simpl::AbstractBlock{N}) where N
    inst = []
    generate_inst!(inst, basicstyle(qc_simpl), [1:N...], Int[])
    return inst
end

function generate_inst!(inst, qc_simpl::ChainBlock, locs, controls)
    for block in subblocks(qc_simpl)
        generate_inst!(inst, block, locs, controls)
    end
end

function generate_inst!(inst, blk::PutBlock{N,M}, locs, controls) where {N,M}
    generate_inst!(inst, blk.content, sublocs(blk.locs, locs), controls)
end

function generate_inst!(inst, blk::ControlBlock{N,GT,C}, locs, controls) where {N,GT,C}
    any(==(0),blk.ctrl_config) && error("Inverse Control used in Control gate context") 
    generate_inst!(inst, blk.content, sublocs(blk.locs, locs), [controls..., sublocs(blk.ctrl_locs, locs)...])
end

function generate_inst!(inst, m::Measure{N}, locs, controls) where N
    # memory:  List of memory slots in which to store the measurement results (mustbe the same length as qubits).  
    mlocs = sublocs(n.locations isa AllLocs ? [1:N...] : [n.locations...], locs)
    (m.operator isa ComputationalBasis) || error("measuring an operator is not supported")
    (m.postprocess isa NoPostProcess) || error("postprocessing is not supported")
    (length(controls) == 0) || error("controlled measure is not supported")
    push!(inst, Dict("name"=>"measure", "qubits"=>mlocs .- 1, "memory"=>zeros(length(mlocs))))
end

# IBMQ Chip only supports ["id", "u1", "u2", "u3", "cx"]

# x, y, z and control x, y, z, id, t, swap and other primitive gates
for (GT, NAME, MAXC) in [(:XGate, "x", 2), (:YGate, "y", 2), (:ZGate, "z", 2),
                         (:I2Gate, "id", 0), (:TGate, "t", 0), (:SWAPGate, "swap", 0)]
    @eval function generate_inst!(inst, ::$GT, locs, controls)
        if length(controls) <= $MAXC
            push!(inst, Dict("name"=>"c"^(length(controls))*$NAME, "qubits"=>[controls..., locs...] .- 1))
        else
            error("too many control bits!")
        end
    end
end

# rotation gates
for (GT, NAME, PARAMS, MAXC) in [(:(RotationGate{1, T, XGate} where T), "u3", :([b.theta, -π/2, π/2]), 0),
                           (:(RotationGate{1, T, YGate} where T), "u2", :([b.theta, 0, 0]), 0),
                           (:(RotationGate{1, T, ZGate} where T), "u1", :([b.theta]), 0),
                           (:(ShiftGate), "u1", :([b.theta]), 1),
                           (:(HGate), "u2", :([0, π]), 0),
                          ]
    @eval function generate_inst!(inst, b::$GT, locs, controls)
        if length(controls) <= $MAXC
            push!(inst, Dict("name"=>"c"^(length(controls))*$NAME, "qubits"=>[controls..., locs...] .- 1, "params"=>$PARAMS))
        else
            error("too many control bits! got $controls (length > $($(MAXC)))")
        end
    end
end

sublocs(subs, locs) = [locs[i] for i in subs]

function basicstyle(blk::AbstractBlock)
	YaoBlocks.Optimise.simplify(blk, rules=[YaoBlocks.Optimise.to_basictypes])
end

function inst2qbir(inst)
    n = maximum(x->maximum(x["qubits"]), inst) + 1
    chain(n, map(inst) do x
        name, locs = x["name"], x["qubits"] .+ 1
        nc = 0
        while name[nc+1] == 'c' && nc<length(name)
            nc += 1
        end
        if nc > 0
            control(n, locs[1:nc], locs[nc+1:end]=>name_index(name[nc+1:end], get(x, "params", nothing)))
        else
            put(n, locs=>name_index(name, get(x, "params", nothing)))
        end
    end)
end

function name_index(name, params=nothing)
    if name == "u1"
        U1(params...)
    elseif name == "u2"
        U2(params...)
    elseif name == "u3"
        U3(params...)
    elseif name == "id"
        I2
    elseif name == "x"
        X
    elseif name == "y"
        Y
    elseif name == "z"
        Z
    elseif name == "t"
        T
    elseif name == "swap"
        SWAP
    else
        error("gate type `$name` not defined!")
    end
end