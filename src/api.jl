using HTTP, JSON
using Yao, YaoBlocks
const headers = (("content-type", "application/json"), ("Accept", "application/json"))

struct IBMQUser #store other info here
    id::String
end

struct Qobj
    data::Dict{String, Any}
end

struct IBMQReg{B} <: AbstractRegister{B}
    id::String
    device::String
    nactive::B
    nqubits::B
end

struct Job
    reg::IBMQReg
    data::Qobj
    jobid::String
end

Yao.nactive(reg::IBMQReg) = reg.nactive
Yao.nqubits(reg::IBMQReg) = reg.nqubits
# Yao.device(reg::IBMQReg) = reg.device

function apply!(reg::IBMQReg, qc::Array{ChainBlock{N}}) where N
    qobj = yaotoqobj(qc, reg.device)
    job = run(reg, qobj)
end
"""
Login method
"""
function authenticate(token::String = "") # todo : save the token
    if length(token) == 0
        println("IBM QE token > ")
        token = readline()
    end
    conf = (readtimeout = 1,     # todo handle timeouts better
        pipeline_limit = 4,
        retry = false,
        redirect = false)

    url = "https://api.quantum-computing.ibm.com/api/users/loginWithToken"
    req = Dict("apiToken" => token)
    print("Logging You in...")
    response = HTTP.post(url, headers, JSON.json(req); conf...)
    
    response_json = String(response.body)
    response_parsed = JSON.parse(response_json)
    if response.status == 200
        println("✔")
    else
        println("❌")
    end
    IBMQUser(response_parsed["id"])
end

"""
Get backends info
"""
function createreg(user::IBMQUser)
    id = user.id
    url_back = "https://api.quantum-computing.ibm.com/api/Network/ibm-q/Groups/open/Projects/main/devices/v/1?access_token=$(id)"
    println("Fetching Backends...")
    response_back = HTTP.get(url_back)
    if response_back.status == 200
        println("✔")
    else
        println("❌")
        return
    end
    response_back_json = String(response_back.body)
    response_back_parsed = JSON.parse(response_back_json)
    id_back = [i["backend_name"] for i in response_back_parsed]
    confirm = false
    while !confirm
        println("The following backends are available > ")
        for i in enumerate(id_back)
            println(i)
        end
        println("Enter the serial number of the backend you wish to use")
        backend_no = readline()
        device_info = response_back_parsed[parse(Int64, backend_no)]
        n_qubits=device_info["n_qubits"]
        println("n_qubits = $(n_qubits)")
        println("basis_gates=$(device_info["basis_gates"])")
        println("Confirm? (Y/N)")
        conf = readline()
        if conf == "Y" || conf == "y"
            return IBMQReg(id, id_back[parse(Int, backend_no)], n_qubits, n_qubits)
        else
            confirm = false
        end
    end
end

function run(reg::IBMQReg, qobj::Qobj)
    url = "https://api.quantum-computing.ibm.com/api/Network/ibm-q/Groups/open/Projects/main/Jobs?access_token=$(reg.id)" 

    req = Dict("backend" => Dict("name" => reg.device), "allowObjectStorage" => true, "shareLevel"=> "none")
    print("Connecting to $(reg.device)...")
    request = HTTP.post(url , headers, JSON.json(req))
    if request.status == 200
        println("✔")
    else
        println("❌")
    end
    response_json = String(request.body)
    response_parsed = JSON.parse(response_json)
    
    objectinfo = response_parsed["objectStorageInfo"]
    upload_url = objectinfo["uploadUrl"]
    jobid = response_parsed["id"]

    print("Preparing Data...")
    json = JSON.json(qobj.data)
    println("✔")

    print("Uploading circuit to $(reg.device)...")
    ckt_upload = HTTP.put(upload_url, [], json) 
    if ckt_upload.status == 200
        println("✔")
        print("Notifying backend...")
        # Notify the backend that the job has been uploaded
        url = "https://api.quantum-computing.ibm.com/api/Network/ibm-q/Groups/open/Projects/main/Jobs/$(jobid)/jobDataUploaded?access_token=$(reg.id)"
        json_step4 ="""{
                "data": "none",
                "json": "none"
                }"""
        request = HTTP.post(url, headers, json_step4)
        println("✔")
        return Job(reg, qobj, jobid)
    else 
        println("❌")
    end
end

function status(job::Job)
    jobid = job.jobid
    id = job.reg.id
    url = "https://api.quantum-computing.ibm.com/api/Network/ibm-q/Groups/open/Projects/main/Jobs/$(jobid)?access_token=$(id)"
    result = HTTP.get(url)
    response_json = String(result.body)
    response_parsed = JSON.parse(response_json)
    return response_parsed["status"]
end

# get result
function getresult(job::Job)
    jobid = job.jobid
    id = job.reg.id
    url = "https://api.quantum-computing.ibm.com/api/Network/ibm-q/Groups/open/Projects/main/Jobs/$(jobid)/resultDownloadUrl?access_token=$(id)"
    print("Connecting to $(job.reg.device)...")
    result = HTTP.get(url)
    if result.status == 200
        println("✔")
    else
        println("❌")
    end
    response_json = String(result.body)
    response_parsed = JSON.parse(response_json)
    downloadUrl = response_parsed["url"]
    final_res = HTTP.get(downloadUrl)
    
    if final_res.status == 200
        print("Fetching result from $(job.reg.device)...")
        # STEP8: Confirm the data was downloaded
        url = "https://api.quantum-computing.ibm.com/api/Network/ibm-q/Groups/open/Projects/main/Jobs/$(jobid)/resultDownloaded?access_token=$(id)"
        json_step8 = """{
            "data": "none",
            "json": "none"
            }"""
        result = HTTP.post(url, headers, json_step8)
        if result.status == 200
            println("✔")
        else
            println("❌")
        end
        response_json = String(final_res.body)
        response_parsed = JSON.parse(response_json)
        res = response_parsed["results"]
    end
end






















# # check if device is online
# function is_online(id_back::Array, device_name::String)
#     return device in id_back 
# end

# #  info (dict): dictionary sent by the backend containing the code to run 
# # or we can have it has the number of qubits in our circuit
# function can_run_experiment(info::Dict, response_back_parsed, device::Dict)
#     info['nq'] <= device["n_qubits"] ? true : false
# end
# json = """{
#     "qobj_id": "exp123_072018",
#     "schema_version": "1.0.0",
#     "type": "QASM",
#     "header": {
#         "description": "Set of Experiments 1",
#         "backend_name": "ibmq_qasm_simulator"},
#     "config": {
#         "shots": 1024,
#         "memory_slots": 1,
#         "init_qubits": true
#         },
#     "experiments": [
#         {
#         "header": {
#             "memory_slots": 1,
#             "n_qubits": 2,
#             "clbit_labels": [["c1", 0]],
#             "qubit_labels": [null,["q", 0],["q",1]]
#             },
#         "config": {},
#         "instructions": [
#             {"name": "h", "qubits": [1]},
#             {"name": "id", "qubits": [2]},
#             {"name": "s", "qubits": [1]}
#             ]
#         }
#         ]    
# }"""
