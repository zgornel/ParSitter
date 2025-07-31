function sat_function(args...; kwargs...)
    return "sat_function"
end

#sat_function_2 = sat_function  ## Warning! this is not parsed as a definition

sat_function_2(args...; kwargs...) = begin
    sat_function(; kwargs...)
    return "sat_function_3"
end


sat_function_3() = begin end
