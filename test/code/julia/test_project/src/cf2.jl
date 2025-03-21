function cf2_function(args...;kwargs...)
    return "cf2_function"
end

# Call to cf1.jl
print(devnull, cf1_function_2())

# Calls to kb.jl
print(devnull, KB_CONST)
kb_function(KB_CONST)

#Call to pe.jl
struct CF2Type <: AbstractPEType  # type inheritance
    y
end

print(devnull, PEType2(0.0))  # constructor call

# Calls to u.jl
print(devnull, UType2())
print(devnull, u_function_2(u_function_3()))

using .TestModuleJulia
foo_in_a_module(1,2,3)  # call directly from module
