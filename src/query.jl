using EzXML
using AbstractTrees
using Combinatorics
using DataStructures
using AutoHashEquals

const DEFAULT_CAPTURE_SYM = "@"

_strip_spaces(text; maxlen = 80) = begin
    _txt = replace(text, r"[\s]+" => " ")
    _txt[1:min(maxlen, length(_txt))]
end

# merge! for 2 MultiDicts
Base.merge!(md1::MultiDict{K, V}, md2::MultiDict{K, V}) where {K, V} = begin
    for (k, v2) in md2
        v1 = get(md1, k, V[])
        if !haskey(md1, k)
            for vi in v2
                push!(md1, k => vi)  # add all values from md2
            end
        else
            for vi in setdiff(v2, v1)  # add different values form md2
                push!(md1, k => vi)
            end
        end
    end
end

# AbstractTrees interface for tree-sitter generated XML ASTs
AbstractTrees.children(t::EzXML.Node) = collect(EzXML.eachelement(t));
AbstractTrees.nodevalue(t::EzXML.Node) = (
    t.name,
    "0x" * string(hash(t.ptr); base = 16),
    (row = ("$(t["srow"]):$(t["erow"])"), col = "($(t["scol"]):$(t["ecol"]))"),
    _strip_spaces(t.content) |> x -> ifelse(length(x) >= 20, x[1:min(length(x), 20)] * "...", x),
)
AbstractTrees.parent(t::EzXML.Node) = t.parentnode
AbstractTrees.nextsibling(t::EzXML.Node) = EzXML.nextelement(t)
AbstractTrees.prevsibling(t::EzXML.Node) = EzXML.prevelement(t)


# AbstractTrees interface for Tuple-based S-expressions (query trees)
@auto_hash_equals struct TreeQueryExpr{T}
    head::T
    children::Vector{TreeQueryExpr}
end

AbstractTrees.nodevalue(se::TreeQueryExpr) = se.head
AbstractTrees.children(se::TreeQueryExpr) = se.children

"""
    build_tq_tree(t::Tuple)

Build a tree query expression tree out of a nested tuple:
the assumption is that the first element of each tuple is the
head of the expression, the rest are children.
"""
build_tq_tree(v::T) where {T} = TreeQueryExpr(v, TreeQueryExpr[])
build_tq_tree(t::TreeQueryExpr) = t
build_tq_tree(t::NTuple{N, T}) where {N, T} = begin
    if length(t) == 1
        return TreeQueryExpr{T}(t[1], TreeQueryExpr{T}[])
    elseif length(t) > 1
        return TreeQueryExpr{T}(t[1], TreeQueryExpr{T}[build_tq_tree(ti) for ti in t[2:end]])
    else
        @error "Input tuple is empty."
    end
end
build_tq_tree(t::Tuple) = begin
    if length(t) == 1
        return TreeQueryExpr(t[1], TreeQueryExpr[])
    elseif length(t) > 1
        return TreeQueryExpr(t[1], TreeQueryExpr[build_tq_tree(ti) for ti in t[2:end]])
    else
        @error "Input tuple is empty."
    end
end


"""
Convert a tree `t` to a `TreeQueryExpr`. The node value is returned
by `nodevalue` and children of the node returned by `children`.
"""
Base.convert(
    ::Type{TreeQueryExpr},
    t::S;
    nodevalue = AbstractTrees.nodevalue,
    children = AbstractTrees.children
) where {S} = begin
    c = children(t)
    if length(c) > 0
        return TreeQueryExpr(nodevalue(t), TreeQueryExpr[Base.convert(TreeQueryExpr, ci; nodevalue) for ci in c])
    else # length(c) == 0
        return TreeQueryExpr(nodevalue(t), TreeQueryExpr[])
    end
end

"""
Convert from a tree-like object to a Tuple.
```
using ParSitter
tt=(1,2,(3,(4,5,(6,),7,5)));
tq = ParSitter.build_tq_tree(tt)
tt2 = convert(Tuple, tq)
```
"""
Base.convert(
    ::Type{Tuple},
    t::S;
    nodevalue = AbstractTrees.nodevalue,  # note: this is apparently not used
    children = AbstractTrees.children     # and the default AbstractTrees.nodevalue is used
) where {S} = begin
    _destructure(t) = ifelse(length(t) == 1, first(t), t)
    c = children(t)
    if length(c) > 1
        return (nodevalue(t), [_destructure(Base.convert(Tuple, ci)) for ci in c]...)
    elseif length(c) == 1
        return (nodevalue(t), Base.convert(Tuple, only(c)))
    else # length(c) == 0
        return (nodevalue(t),)
    end
end


"""
Checks that a query tree does not contain duplicate capture keys.
"""
function check_tq_tree(tree::TreeQueryExpr)
    captures = [n for n in PreOrderDFS(tree) if ParSitter.is_capture_node(n).is_match]
    return @assert length(captures) == length(unique(captures)) "Found non-unique capture keys in query"
end


"""
    build_xml_tree(tree_sitter_xml_ast::String)

Postprocesses and parse the tree-sitter XML output to
something that can be traversed to match a given query.
"""
function build_xml_tree(tree_sitter_xml_ast::String)
    tmp = replace(tree_sitter_xml_ast, "\n" => "")
    return xml = EzXML.parsexml(tmp)
end

"""
    is_capture_node(n; capture_sym=DEFAULT_CAPTURE_SYM)

Function that checks whether a node is a 'capture node' i.e. value of the form "match@capture_key"
and returns a `NamedTuple` with the result and the capture key string
```
julia> ParSitter.is_capture_node("value@capture_key")
(is_match = true, capture_key = "capture_key")

julia> ParSitter.is_capture_node("value@capture_key", capture_sym="@@")
(is_match = false, capture_key = nothing)
```
"""
is_capture_node(n::T; capture_sym = DEFAULT_CAPTURE_SYM) where {T <: AbstractString} = begin
    is_match = !isnothing(match(Regex("[.]*$(capture_sym)[.]*"), n))
    capture_key = is_match ? string(split(n, capture_sym)[2]) : ""
    return (; is_match, capture_key)
end
is_capture_node(n::TreeQueryExpr{<:AbstractString}; capture_sym = DEFAULT_CAPTURE_SYM) = is_capture_node(n.head; capture_sym)
is_capture_node(n; capture_sym = DEFAULT_CAPTURE_SYM) = (is_match = false, capture_key = "")


"""
    function match_tree(target_tree,
                        query_tree;
                        match_cache=Dict(),
                        captured_symbols=MultiDict(),
                        match_type=:strict,
                        is_capture_node=is_capture_node,
                        target_tree_nodevalue=AbstractTrees.nodevalue,
                        query_tree_nodevalue=AbstractTrees.nodevalue,
                        capture_function=AbstractTrees.nodevalue,
                        node_comparison_yields_true=(args...)->false)

Function that searches a `query_tree` into a `target_tree`. It returns a vector
of subtree matches, where each element is a `Tuple` that contains the result
of the match, any captured values and the trees that were compared.
To capture a value, the function `is_capture_node` must return `true` for a given query node.
One example is using query nodes of  the form `"nodevalue@capture_variable"`.
In the matching process, the query and target node values are extracted
using `query_tree_nodevalue` and `target_tree_nodevalue` respectively and compared.
If they match, the `target_tree` node value is captured by applying `capture_function` to the node
and a `MultiDict("capture_variable"=>captured_target_node_value))`.
Tree comparisons are also hashed and the result as well as captured symbols are stored
in `match_cache` for quick retrieval.
# Example
```
julia> using ParSitter
       using AbstractTrees

       _query_tree_nodevalue(n) = ParSitter.is_capture_node(n).is_match ? split(n.head, "@")[1] : n.head
       _target_tree_nodevalue(n)=string(n.head)
       _capture_on_empty_query_value(t1,t2) = ParSitter.is_capture_node(t2).is_match && isempty(_query_tree_nodevalue(t2))

       my_matcher(t,q) = ParSitter.match_tree(
                              ParSitter.build_tq_tree(t),
                              ParSitter.build_tq_tree(q);
                              target_tree_nodevalue=_target_tree_nodevalue,
                              query_tree_nodevalue=_query_tree_nodevalue,
                              capture_function=n->n.head,
                              node_comparison_yields_true=_capture_on_empty_query_value)

       query = ("1@v0", "2", "@v2")   # - query means: capture in "v0" if target value is 1, match on 2, capture any symbol in "v2"

       t=(1,2,10); my_matcher( t, query)[1:2] |> println
       t=(10,2,11); my_matcher( t, query)[1:2] |> println
       t=(1,2,3,4,5); my_matcher( t, query)[1:2] |> println
(true, MultiDict{Any, Any}(Dict{Any, Vector{Any}}("v2" => [10], "v0" => [1])))
(false, MultiDict{Any, Any}(Dict{Any, Vector{Any}}("v2" => [11])))
(true, MultiDict{Any, Any}(Dict{Any, Vector{Any}}("v2" => [3], "v0" => [1])))
```
"""
function match_tree(
        target_tree,
        query_tree;
        match_cache = Dict(),
        captured_symbols = MultiDict(),
        match_type = :strict,
        is_capture_node = is_capture_node,
        target_tree_nodevalue = AbstractTrees.nodevalue,
        query_tree_nodevalue = AbstractTrees.nodevalue,
        capture_function = AbstractTrees.nodevalue,
        node_comparison_yields_true = (args...) -> false
    )
    # Initializations
    c1 = children(target_tree)
    c2 = children(query_tree)
    n1 = target_tree_nodevalue(target_tree)
    n2 = query_tree_nodevalue(query_tree)
    is_capture_node_q, capture_key = is_capture_node(query_tree)
    is_capture_node_t, _ = is_capture_node(target_tree)
    # Checks whether node values match or, we have a capture node with a capture condition
    found::Bool = (n1 == n2) || node_comparison_yields_true(target_tree, query_tree)
    # Check hashes, return if found
    _hash = hash((target_tree, query_tree))
    if _hash in keys(match_cache)
        return match_cache[_hash]..., target_tree
    end
    # Start recursion
    if length(c1) == length(c2) == 0
        if is_capture_node_q
            if is_capture_node_t
                @warn "Illegal use of a capture node in the target tree, found at node $target_tree"
            else
                # Add captured symbols only if node values match or the node comparison
                # function yields a true value (i.e. for a global capture symbol or similar)
                found && push!(captured_symbols, capture_key => capture_function(target_tree))
            end
        end
        push!(match_cache, _hash => (found, captured_symbols))
        return found, captured_symbols, target_tree
    elseif length(c1) >= length(c2) && treeheight(c1) >= treeheight(c2)
        if is_capture_node_q
            if is_capture_node_t
                @warn "Illegal use of a capture node in the target tree, found at node $target_tree"
            else
                found && push!(captured_symbols, capture_key => capture_function(target_tree))
            end
        end
        if match_type == :strict
            # All query subtrees must match the target subtrees: in the same order,
            # up to the last query tree. The rest of the target subtrees are ignored.
            _match_cache = Dict()
            subtree_results = [
                match_tree(
                        t, q;
                        match_cache = _match_cache,
                        captured_symbols,
                        match_type,
                        is_capture_node,
                        target_tree_nodevalue,
                        query_tree_nodevalue,
                        capture_function,
                        node_comparison_yields_true
                    )
                    for (t, q) in zip(c1, c2)
            ]
            for (subtree_found, subtree_captures, _) in subtree_results
                merge!(captured_symbols, subtree_captures)
                found &= subtree_found
            end
        else # match_type == :nonstrict
            # Combinations of subtrees of the target tree are matched against
            # the query tree; if any of them matches, the function returns
            subtrees_found = Bool[]
            _match_cache = Dict()
            for c1c in combinations(c1, length(c2))
                _captured_symbols = MultiDict()
                subtree_results = [
                    match_tree(
                            t, q;
                            match_cache = _match_cache,
                            captured_symbols = _captured_symbols,
                            match_type = :nonstrict,
                            is_capture_node,
                            target_tree_nodevalue,
                            query_tree_nodevalue,
                            capture_function,
                            node_comparison_yields_true
                        )
                        for (t, q) in zip(c1c, c2)
                ]
                # All subtrees of a specific combination must match
                _found = all(first, subtree_results)
                if _found
                    for (_, subtree_captures, _) in subtree_results
                        merge!(captured_symbols, subtree_captures)  # add matched symbols
                    end
                end
                push!(subtrees_found, _found)  # store whether subtree combination was found
            end
            # Resolve matching:
            # - any of the matched subtrees (from combinations will do)
            # - logical AND is used to trasmit finding recursively upwards
            found &= any(subtrees_found)
        end
        push!(match_cache, _hash => (found, captured_symbols))
        return found, captured_symbols, target_tree
    else
        push!(match_cache, _hash => (false, captured_symbols))
        return false, captured_symbols, target_tree
    end
end


"""
Query a tree with another tree. This will match the `query_tree`
with all substrees of `target_tree`. Both trees should support the
`AbstractTrees` interface.

# Example
```julia
julia> using ParSitter
       using AbstractTrees

       query = ("1@v0", "2", "@v2")   # - query means: capture in "v0" if target value is 1, match on 2, capture any symbol in "v2"
       target = (1, 2, 3, (10, 2, 3)) # - only the (1,2,3) subtree will match, the second will not bevause of the 10;
                                      # - @v2 will always capture values (due to `_capture_on_empty_query_value`)
       query_tq = ParSitter.build_tq_tree(query)
       target_tq = ParSitter.build_tq_tree(target)

       _query_tree_nodevalue(n) = ParSitter.is_capture_node(n).is_match ? split(n.head, "@")[1] : n.head
       _target_tree_nodevalue(n) = string(n.head)
       _capture_on_empty_query_value(t1,t2) = ParSitter.is_capture_node(t2).is_match && isempty(_query_tree_nodevalue(t2))
       print_tree(target_tq); println("---")
       print_tree(query_tq); println("---")
       r=ParSitter.query(target_tq,
                         query_tq;
                         match_type=:strict,
                         target_tree_nodevalue=_target_tree_nodevalue,
                         query_tree_nodevalue=_query_tree_nodevalue,
                         capture_function=n->n.head,
                         node_comparison_yields_true=_capture_on_empty_query_value)
       map(t->t[1:2], r)
1
├─ 2
├─ 3
└─ 10
   ├─ 2
   └─ 3
---
"1@v0"
├─ "2"
└─ "@v2"
---
6-element Vector{Tuple{Bool, MultiDict{Any, Any}}}:
 (1, MultiDict{Any, Any}(Dict{Any, Vector{Any}}("v2" => [3], "v0" => [1])))
 (0, MultiDict{Any, Any}(Dict{Any, Vector{Any}}()))
 (0, MultiDict{Any, Any}(Dict{Any, Vector{Any}}()))
 (0, MultiDict{Any, Any}(Dict{Any, Vector{Any}}("v2" => [3])))
 (0, MultiDict{Any, Any}(Dict{Any, Vector{Any}}()))
 (0, MultiDict{Any, Any}(Dict{Any, Vector{Any}}()))

julia> r=ParSitter.query(target_tq,
                         query_tq;
                         match_type=:nonstrict,
                         target_tree_nodevalue=_target_tree_nodevalue,
                         query_tree_nodevalue=_query_tree_nodevalue,
                         capture_function=n->n.head,
                         node_comparison_yields_true=_capture_on_empty_query_value)
       map(t->t[1:2], r)
6-element Vector{Tuple{Bool, DataStructures.MultiDict{Any, Any}}}:
 (1, DataStructures.MultiDict{Any, Any}(Dict{Any, Vector{Any}}("v2" => [3, 10], "v0" => [1])))
 (0, DataStructures.MultiDict{Any, Any}(Dict{Any, Vector{Any}}()))
 (0, DataStructures.MultiDict{Any, Any}(Dict{Any, Vector{Any}}()))
 (0, DataStructures.MultiDict{Any, Any}(Dict{Any, Vector{Any}}("v2" => [3])))
 (0, DataStructures.MultiDict{Any, Any}(Dict{Any, Vector{Any}}()))
 (0, DataStructures.MultiDict{Any, Any}(Dict{Any, Vector{Any}}()))
```
"""
function query(
        target_tree,
        query_tree;
        match_type = :strict,
        is_capture_node = is_capture_node,
        target_tree_nodevalue = AbstractTrees.nodevalue,
        query_tree_nodevalue = AbstractTrees.nodevalue,
        capture_function = AbstractTrees.nodevalue,
        node_comparison_yields_true = (args...) -> false,
        match_cache = Dict()
    )
    # Checks
    check_tq_tree(query_tree)
    matches = []
    for tn in PreOrderDFS(target_tree)
        m = match_tree(
            tn,
            query_tree;
            match_type,
            is_capture_node,
            target_tree_nodevalue,
            query_tree_nodevalue,
            capture_function,
            node_comparison_yields_true,
            match_cache
        )
        push!(matches, m)
    end
    return matches
end


"""
    Function that returns captured values from a query. If the key does not
    exist `nothing` is returned.
"""
get_capture(qr::AbstractVector, key) = begin
    qrf = filter(first, qr)  # get only matched queries
    result = []
    for qri in qr
        try
            r = get_capture(qri, key)
            !isnothing(r) && push!(result, r)
        catch e
            rethrow()
        end
    end
    ifelse(!isempty(result), result, nothing)
end

get_capture(qr::Tuple, key) = begin
    _, captures = qr
    values = get(captures, key, nothing)
    values == nothing && return nothing
    if values isa Vector && length(values) > 1
        throw(ErrorException("Ambigous capture, more than 1 match for key \"$key\""))
    end
    return first(value for value in values)
end
