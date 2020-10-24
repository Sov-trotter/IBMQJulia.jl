export U1, U2, U3

# Single qubit unitary gates
# https://github.com/Qiskit/openqasm/blob/master/examples/generic/qelib1.inc
# 1-parameter 0-pulse single qubit gate
mutable struct U1{T<:Number} <: PrimitiveBlock{2}
    lambda::T
end

# 2-parameter 1-pulse single qubit gate
mutable struct U2{T<:Number} <: PrimitiveBlock{2}
    phi::T
    lambda::T
end

# 3-parameter 2-pulse single qubit gate
mutable struct U3{T<:Number} <: PrimitiveBlock{3}
    theta::T
    phi::T
    lambda::T
end

Base.:(==)(u1_1::U1, u1_2::U1) = u1_1.lambda == u1_2.lambda
Base.:(==)(u2_1::U2, u2_2::U2) = u2_1.phi == u2_2.phi && u2_1.lambda == u2_2.lambda
Base.:(==)(u3_1::U3, u3_2::U3) = u3_1.theta == u3_2.theta && u3_1.phi == u3_2.phi && u3_1.lambda == u3_2.lambda

function Yao.mat(::Type{T}, u1::U1) where T
    λ = u1.lambda
    
    T[1     0;
      0     exp(im*λ)]
end

function Yao.mat(::Type{T}, u2::U2) where T
    ϕ, λ = u2.phi, u2.lambda
    
    T[1/√2                (-exp(im*λ))/√2;
      (exp(im*ϕ))/√2      (exp(im*(ϕ+λ)))/√2]
end

function Yao.mat(::Type{T}, u3::U3) where T
    θ, ϕ, λ = u3.theta, u3.phi, u3.lambda
    
    T[cos(θ/2)                -sin(θ/2)*exp(im*λ) ;
      sin(θ/2)*exp(im*ϕ)      cos(θ/2)*exp(im*(ϕ+λ))]
end

Yao.iparams_eltype(::U1{T}) where T = T
Yao.iparams_eltype(::U2{T}) where T = T
Yao.iparams_eltype(::U3{T}) where T = T

Yao.getiparams(u1::U1{T}) where T = (u1.lambda)
Yao.getiparams(u2::U2{T}) where T = (u2.phi, u2.lambda)
Yao.getiparams(u3::U3{T}) where T = (u3.theta, u3.phi, u3.lambda)

function Yao.setiparams!(u1::U1{T}, λ) where T
    u1.lambda = λ
    return u1
end

function Yao.setiparams!(u2::U2{T}, ϕ, λ) where T
    u2.phi = ϕ
    u2.lambda = λ
    return u2
end

function Yao.setiparams!(u3::U3{T}, θ, ϕ, λ) where T
    u3.theta = θ
    u3.phi = ϕ
    u3.lambda = λ
    return u3
end

YaoBlocks.@dumpload_fallback U1 U1
YaoBlocks.@dumpload_fallback U2 U2
YaoBlocks.@dumpload_fallback U3 U3
