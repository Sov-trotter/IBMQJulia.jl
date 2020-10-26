@testset "Login" begin
    @test user isa IBMQJulia.IBMQUser 
    @test user.id isa String
end

@testset "Backends" begin
    @test reg isa IBMQJulia.IBMQReg    
    @test reg.device == "ibmq_qasm_simulator"
    @test reg.id == user.id
end

@testset "job" begin
    @test job isa IBMQJulia.Job
    @test job.reg == reg
    @test job.data isa IBMQJulia.Qobj
    @test job.data.data["experiments"][1]["instructions"] == IBMQJulia.generate_inst(qc)
    @test job.jobid isa String
end

@testset "status" begin
    @test stat == "COMPLETED" || stat == "RUNNING" || stat == "QUEUED"
end

if stat == "COMPLETED"
    @testset "result" begin
        @test res isa Array{Any, 1}
        @test res[1] isa Dict{String, Any}
        @test res[1]["status"] == "DONE"
        @test res[1]["success"] == true
    end
end
