abstract type AbstractCF1Type end  # abstract type

struct CF1Type end  # singleton

function cf1_function(args...; kwargs...)
    return "cf1_function"
end

cf1_function_2(args...; kwargs...) = begin
    "cf1_function_2" * " calls " *  cf1_function(args...)  # function call
end

cf1_function_3(args...; kwargs...) = begin
    "cf1_function_3" * " calls $(cf1_function(args...))"  # more complicated function call
end

import .TestModuleJulia

TestModuleJulia.foo_in_a_module()  # call with name of module

TestModuleJulia.foo_in_a_module(x::Int) = begin
    "foo_in_a_module (method Int)"
end

TestModuleJulia.foo_in_a_module(0);
