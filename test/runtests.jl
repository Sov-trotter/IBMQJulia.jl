using IBMQJulia
using SimpleMock
using Yao, YaoBlocks
using Test

# todo add tests wrt standard circuits(qft etc) to confirm that qobj is correct
# verify the results
qc = chain(1, put(1=>I2))
test_token = "4b108e35df658648486a3a66c3ccf1e66cd3005c97ab2016c9b1ceeec64802c7052325952dd02a01b73ca6e28613c36b7e87c0a854ebae1dc434a07fcfcc7c7b"  
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
