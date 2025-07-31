module TestModuleJulia

export foo_in_a_module

foo_in_a_module(args...; kwargs...) = begin
    return "foo_in_a_module"
end

foo_in_a_module();
end
