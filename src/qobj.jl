#phase :verify
function yaotoqobj(qc::Array{ChainBlock{N}}, device::String; nshots=1024) where N
    nslots = 1
    main_header = Dict("description"=>"Set of Experiments 1", "backend_name" => "$(device)")
    main_config = Dict("shots"=>nshots, "memory_slots"=>nslots, "init_qubits"=> true)
    experiments = collect(generate_experiment(i) for i in qc)
    data = Dict("qobj_id" => "foo", "schema_version"=>"1.0.0", "type"=>"QASM", "header"=>main_header, "config"=>main_config, "experiments"=>experiments)
    Qobj(data)
end

function generate_experiment(qc::ChainBlock)
    n_qubits = nqubits(qc)
    n_classical_reg = 2 # figure out this info
    nslots=1
    c_label = [["c", i] for i in 0:n_classical_reg-1]
    q_label = [["q", i] for i in 0:n_qubits-1]
    exp_inst = generate_inst(qc)
    exp_header = Dict("memory_slots"=>nslots, "n_qubits"=>n_qubits, "clbit_labels"=>c_label, "qubit_labels"=>q_label)
    experiment = Dict("header"=>exp_header, "config"=>Dict(), "instructions"=>exp_inst)
    return experiment    
end

function generate_inst(qc::ChainBlock)
    inst = []
    for block in subblocks(qc)
        if block isa Union{PutBlock{N, M, ChainBlock{M}}, ChainBlock{O}} where {N, M, O}
            push!(inst, generate_inst(block)...)
        else
            push!(inst, generate_inst(block))
        end
    end
    return inst
end

function generate_inst(blk::Union{PutBlock, RepeatedBlock})
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






















# memory_slots: Number of classical memory slots used in this job.  Memory slotsare used to record the results of 
#                 qubit measurements and read out at the end of an experiment. They cannot be used for feedback (those are the registers).

# experiments:  List  of  mexperiment  sequences  to  run.   
#             Each  experiment  is  an experiment data structure.
#             Each experiment is run once in the order that they are  specified  in  this  list  
#             and  then  the  sequence  is  repeated  until  the  specifiednumber of shots has been performed.

# header: User-defined structure that contains metadata on the job andis notusedby the backend.  The headerwill be passed through to the result data structure unchanged.
#         For example, this may contain a description of the full job and/orthe backend that the experiments were compiled for.

#         // --- QE Standard Gates ---

#         // Pauli gate: bit-flip
#         gate x a { u3(pi,0,pi) a; }
#         // Pauli gate: bit and phase flip
#         gate y a { u3(pi,pi/2,pi/2) a; }
#         // Pauli gate: phase flip
#         gate z a { u1(pi) a; }
#         // Clifford gate: Hadamard
#         gate h a { u2(0,pi) a; }
#         // Clifford gate: sqrt(Z) phase gate
#         gate s a { u1(pi/2) a; }
#         // Clifford gate: conjugate of sqrt(Z)
#         gate sdg a { u1(-pi/2) a; }
#         // C3 gate: sqrt(S) phase gate
#         gate t a { u1(pi/4) a; }
#         // C3 gate: conjugate of sqrt(S)
#         gate tdg a { u1(-pi/4) a; }
        
#         // --- Standard rotations ---
#         // Rotation around X-axis
#         gate rx(theta) a { u3(theta,-pi/2,pi/2) a; }
#         // rotation around Y-axis
#         gate ry(theta) a { u3(theta,0,0) a; }
#         // rotation around Z axis
#         gate rz(phi) a { u1(phi) a; }
        
#         // --- QE Standard User-Defined Gates  ---
        
#         // controlled-Phase
#         gate cz a,b { h b; cx a,b; h b; }
#         // controlled-Y
#         gate cy a,b { sdg b; cx a,b; s b; }
#         // controlled-H
#         gate ch a,b {
#         h b; sdg b;
#         cx a,b;
#         h b; t b;
#         cx a,b;
#         t b; h b; s b; x b; s a;
#         }
#         // C3 gate: Toffoli
#         gate ccx a,b,c
#         {
#           h c;
#           cx b,c; tdg c;
#           cx a,c; t c;
#           cx b,c; tdg c;
#           cx a,c; t b; t c; h c;
#           cx a,b; t a; tdg b;
#           cx a,b;
#         }
#         // controlled rz rotation
#         gate crz(lambda) a,b
#         {
#           u1(lambda/2) b;
#           cx a,b;
#           u1(-lambda/2) b;
#           cx a,b;
#         }
#         // controlled phase rotation
#         gate cu1(lambda) a,b
#         {
#           u1(lambda/2) a;
#           cx a,b;
#           u1(-lambda/2) b;
#           cx a,b;
#           u1(lambda/2) b;
#         }
#         // controlled-U
#         gate cu3(theta,phi,lambda) c, t
#         {
#           // implements controlled-U(theta,phi,lambda) with  target t and control c
#           u1((lambda-phi)/2) t;
#           cx c,t;
#           u3(-theta/2,0,-(phi+lambda)/2) t;
#           cx c,t;
#           u3(theta/2,phi,0) t;
#         }
