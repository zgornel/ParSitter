abstract type AbstractPEType end
Base.@kwdef struct PEType <: AbstractPEType
    x::Int = 0
end

mutable struct PEType2
    x
end

PEType2(x::Int) = PEType(x)
PEType2(x::AbstractFloat) = PEType2(0)

function pe_function(args...;kwargs...)
    return "pe_function"
end
