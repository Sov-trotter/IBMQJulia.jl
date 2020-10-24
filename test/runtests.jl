using IBMQJulia
using SimpleMock
using Yao, YaoBlocks
using Test

# todo add tests wrt standard circuits(qft etc) to confirm that qobj is correct
# verify the results
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

@testset "IBMQJulia.jl" begin
    @testset "API" begin
        include("testapi.jl")
    end

    @testset "Qobj" begin
        include("testqobj.jl")
    end
end
