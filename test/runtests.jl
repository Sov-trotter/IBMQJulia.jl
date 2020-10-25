using IBMQJulia
using SimpleMock
using Yao, YaoBlocks
using Test

# todo add tests wrt standard circuits(qft etc) to confirm that qobj is correct
# verify the results
#=
qc = chain(1, put(1=>I2))
test_token = "8e87a83bbe4f5ad0aa953094fb8df853b07b2a86dadf010261eef2a65cd524df29e5bc38bbe2f8064155226bdfb6dcaecc8e3a6a029e402c8c7389ec0cef3574"  
user = authenticate(test_token)   

mock(readline => Mock(() -> "1")) do _
    global reg = createreg(user)
end
job = apply!(reg, [qc])
sleep(10)
stat = status(job)
if stat == "COMPLETED"
    res = getresult(job)
end
=#

@testset "IBMQJulia.jl" begin
    @testset "API" begin
        # include("testapi.jl")
    end

    @testset "Qobj" begin
        include("testqobj.jl")
    end

    @testset "Single Quibit Unitary Gates" begin
        @test isunitary(U1(0.5))
        @test isunitary(U2(0.5, 0.6))
        @test isunitary(U3(0.5, 0.6, 0.4))
        u1 = U1(π/2)
        u2 = U2(π/2, π/6)
        u3 = U3(π/2, π/6, π/4)

        for fs in [u1, u2, u3]
            @test eval(YaoBlocks.parse_ex(dump_gate(fs), 1)) == fs
            @test Yao.iparams_eltype(fs) == Float64 
        end
        @test Yao.getiparams(u1) == (π/2) 
        @test Yao.getiparams(u2) == (π/2, π/6)
        @test Yao.getiparams(u3) == (π/2, π/6, π/4)

    end
end
