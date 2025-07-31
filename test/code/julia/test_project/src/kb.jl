const KB_CONST = "A KB constant"
kb_function(args...; kwargs...) = begin
    return "kb_function"
end

# Call to sat.jl (difficult to catch)
sat_function_2()

# Call to sat.jl (easier to catch)
xx = UType4()
print(devnull, xx)


#Call to u.jl
print(devnull, U_CONSTANT)

# Call within (kb.jl)
print(devnull, kb_function("hello world"))
