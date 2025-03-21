# Constant
const U_CONSTANT = 0

# Define functions:
# - `function keyword`
# - without and `begin` `end`
# - simple inline definition
# - with macro in front of function definition
function u_function(args...;kwargs...)
    return "u_function"
end

u_function_2(args...;kwargs...) = begin
    return "u_function_2"
end

u_function_3(args...;kwargs...) = "u_function_3"


# Define structs and abstract types
abstract type AbstractUType end

struct UType end # singleton

mutable struct UType2  # singleton
end

Base.@kwdef struct UType3  # with macro
    x::String = "utype3"
end

Base.@kwdef mutable struct UType4
    x::String = "utype5"
end


# Methods (extend Base.show)
Base.show(io::IO, t::UType4) = begin
    print(io, "UType4, value = $(t.x)")
end
