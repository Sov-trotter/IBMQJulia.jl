# https://tutorials.yaoquantum.org/dev/
using YaoExtensions

@testset "QFT" begin
    for i in 1:10
        q = qft_circuit(i)
        qobj = IBMQJulia.yaotoqobj([q], "foo_device")
        exp_1 = qobj.data["experiments"] 
        ins = exp_1[1]["instructions"]
        @test qobj isa IBMQJulia.Qobj
        @test qobj.data isa Dict{String,Any}
        @test exp_1 isa Array{Dict{String,Any},1}
        @test ins isa Array{Any, 1}
        @test length(ins) == i*(i+1)/2
        for j in ins
            @test j isa Dict{String, Any} 
            # test individual blocks here 
            # use the YaoBlocks.gate count method for verification/a method synonymous to it can be added in this package also

        end
    end
end

@testset "Quantum Circuit Born Machine" begin
    layer(nbit::Int, x::Symbol) = layer(nbit, Val(x))
    layer(nbit::Int, ::Val{:first}) = chain(nbit, put(i=>chain(Rx(0), Rz(0))) for i = 1:nbit)
    layer(nbit::Int, ::Val{:last}) = chain(nbit, put(i=>chain(Rz(0), Rx(0))) for i = 1:nbit)
    layer(nbit::Int, ::Val{:mid}) = chain(nbit, put(i=>chain(Rz(0), Rx(0), Rz(0))) for i = 1:nbit)
    entangler(pairs) = chain(control(ctrl, target=>X) for (ctrl, target) in pairs)

    function build_circuit(n, nlayers, pairs)
        circuit = chain(n)
        push!(circuit, layer(n, :first))
        for i in 2:nlayers
            push!(circuit, cache(entangler(pairs)))
            push!(circuit, layer(n, :mid))
        end
        push!(circuit, cache(entangler(pairs)))
        push!(circuit, layer(n, :last))
        return circuit
    end
    
    qc = build_circuit(4, 1, [1=>2, 2=>3, 3=>4])
    qobj = IBMQJulia.yaotoqobj([qc], "foo_device")
    exp_1 = qobj.data["experiments"] 
    ins = exp_1[1]["instructions"]
    @test qobj isa IBMQJulia.Qobj
    @test qobj.data isa Dict{String,Any}
    @test exp_1 isa Array{Dict{String,Any},1}
    @test ins isa Array{Any,1}
    for j in ins
        @test j isa Dict{String,Any} 
        # test individual blocks here 
    end
end

@testset "Variational Quantum Eigen Solver" begin
    for n in 3:10
        circuit = dispatch!(variational_circuit(n, n+1),:random)
        qobj = IBMQJulia.yaotoqobj([circuit], "foo_device")
        exp_1 = qobj.data["experiments"] 
        ins = exp_1[1]["instructions"]
        @test qobj isa IBMQJulia.Qobj
        @test qobj.data isa Dict{String,Any}
        @test exp_1 isa Array{Dict{String,Any},1}
        @test ins isa Array{Any,1}
        for j in ins
            @test j isa Dict{String,Any} 
            # test individual blocks here 
        end
        # gatecount(circuit)
    end
end

