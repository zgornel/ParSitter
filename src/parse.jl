struct Directory
    name::String
end

struct File
    name::String
end

struct Code
    code::String
end

# Map from input language to tree-sitter compatible language name
const LANGUAGE_MAP = Dict(
    "python" => "source.python",
    "julia" => "source.julia",
    "c" => "source.c",
    "c#" => "source.csharp",
    "r" => "source.r")

const FILE_EXTENSIONS = Dict(
    "python" => [".py"],
    "julia" => [".jl"],
    "c" => [".c", ".h"],
    "c#" => [".cs"],
    "r" => [".r"])

function check_language(language, lang_map)
    @assert language in keys(lang_map) "Unrecognized language $language, exiting..."
end

Base.isfile(::Nothing) = false
function check_tree_sitter(;system=:Linux,
                            tree_sitter_path=nothing)
    if system==:Linux
        @assert Sys.islinux() "This is not a Linux system."
        @assert isfile("/usr/bin/tree-sitter") ||
                 isfile("/bin/tree-sitter") ||
                 isfile(tree_sitter_path) "tree-sitter not found on system"
    end
end

function _normalize_fs_path(path::String)::String
    result = replace(path, "\\" => "/")
    result = String(strip(result))
    return result;
end


# Returns a tree-sitter command
function _make_parse_code_cmd(code::String, language::String)
    _language = LANGUAGE_MAP[language]
    #return `sh -c "echo '$code' | tree-sitter parse -q -x --scope $_language parse /dev/stdin 2>/dev/null"`
    return pipeline(`tree-sitter parse -q -x --scope $_language /dev/stdin`, stdin=IOBuffer(code), stderr=devnull)
end

# Returns a tree-sitter command
function _make_parse_file_cmd(file::String, language::String)
    _language = LANGUAGE_MAP[language]
    #return `tree-sitter parse -q -x --scope $(_language) $(file) 2'>'/dev/null`
    return pipeline(`tree-sitter parse -q -x --scope $(_language) $(file)`, stderr=devnull)
end


_enable_escape_chars(code) = begin
    # "\n", "\t" in input code are treated as escape chars and not strings
    for ch in ["\\n"=>'\n',"\\t"=>'\t', "\\r"=>'\r']
        code = replace(code, ch[1]=>ch[2])
    end
    return code
end

# Parsing functions (execute tree-sitter commands)
function parse(code::String, language::String; escape_chars=false, print_code=false)
    escape_chars && (code = _enable_escape_chars(code))
    print_code && println("---\n$code\n---\n")
    ts_cmd = _make_parse_code_cmd(code, language)
    out = try
        out = read(ts_cmd, String)
    catch
        @warn "Could not parse code snippet."
        ""
    end
    return replace(out, "\n"=>"")
end

function parse(code::Code, language::String; escape_chars=false, print_code=false)
    return Dict(""=>parse(code.code, language; escape_chars, print_code))
end

function parse(file::File, language::String)
    _file = abspath(_normalize_fs_path(file.name))
    @debug "Parsing file @ $_file ..."
    ts_cmd = _make_parse_file_cmd(_file, language)
    out = try
            read(ts_cmd, String)
          catch
            @warn "Could not parse $_file"
            ""
          end
    return Dict(_file => replace(out, "\n"=>""))
end

function parse(dir::Directory, language::String)
    parses = Dict{String, String}()
    for (root, _ ,files) in walkdir(dir.name)
        for file in files
            if any(endswith(lowercase(file), lowercase(_ext))
                        for _ext in get(FILE_EXTENSIONS, language, []))
                _file = File(joinpath(root, file))
                _parsed = parse(_file, language)
                for (k, v) in _parsed
                    push!(parses, k=>v)
                end
            end
        end
    end
    return parses
end
