module ParSitter

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
    "c#" => "source.csharp")

const FILE_EXTENSIONS = Dict(
    "python" => [".py"],
    "julia" => [".jl"],
    "c" => [".c", ".cxx"],
    "c#" => [".cs"])

const LOCAL_TMP = "tmp/"

function check_language(language, lang_map)
    @assert language in keys(lang_map) "Unrecognized language $language, exiting..."
end


function _normalize_fs_path(path::String)::String
    result = replace(path, "\\" => "/")
    result = String(strip(result))
    return result;
end


# Returns a tree-sitter command
# TODO: Fix this, current workaround is to use the file version
function _make_parse_code_cmd(code::String, language::String, tmpfile::String)
    _language = LANGUAGE_MAP[language]
    return `sh -c "echo '$code' | tree-sitter parse -q -x --scope $_language parse /dev/stdin 2>/dev/null"`
end

# Returns a tree-sitter command
function _make_parse_file_cmd(file::String, language::String)
    _language = LANGUAGE_MAP[language]
    return `tree-sitter parse -q -x --scope $(_language) $(file) 2'>'/dev/null`
end


# Parsing functions (execute tree-sitter commands)
function parse(code::String, language::String)
    tmppath = tempname(LOCAL_TMP, cleanup=false)
    open(tmppath, "w") do io
        write(io, code);
    end
    ts_cmd = _make_parse_file_cmd(abspath(tmppath), language)
    out = try
        out = read(ts_cmd, String)
    catch
        @warn "Could not parse code snippet."
        ""
    end
    rm(tmppath, force=true)
    return replace(out, "\n"=>"")
end

function parse(code::Code, language::String)
    return Dict(""=>parse(code.code, language))
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
            if any(endswith(file, _ext) for _ext in get(FILE_EXTENSIONS, language, []))
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

end # module ParSitter
