using Test
using ParSitter
using Logging
global_logger(ConsoleLogger(stdout, Logging.Error))  # supress test warnings

include("parse.jl")
include("query.jl")
