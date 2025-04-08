using EzXML
using AbstractTrees

const DEFAULT_CAPTURE_SYM="@"

_strip_spaces(text; maxlen=10) = begin
    _txt = replace(text, r"[\s]+"=>" ")
    _txt[1:min(maxlen, length(_txt))]
end

# AbstractTrees interface for tree-sitter generated XML ASTs
AbstractTrees.children(t::EzXML.Node) = collect(EzXML.eachelement(t));
AbstractTrees.nodevalue(t::EzXML.Node) = (t.name,
                                          string(t.ptr),
                                          ("ROW:$(t["srow"]):$(t["erow"])", "COL:$(t["scol"]):$(t["ecol"])"),
                                          _strip_spaces(t.content; maxlen=80)
                                          )
AbstractTrees.parent(t::EzXML.Node) = t.parentnode
AbstractTrees.nextsibling(t::EzXML.Node) = EzXML.nextelement(t)
AbstractTrees.prevsibling(t::EzXML.Node) = EzXML.prevelement(t)


# AbstractTrees interface for Tuple-based S-expressions (query trees)
mutable struct TreeQueryExpr
    head
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
build_tq_tree(v) = TreeQueryExpr(v, TreeQueryExpr[])
build_tq_tree(t::Tuple) = begin
    if length(t) == 1
        return TreeQueryExpr(t[1], TreeQueryExpr[])
    elseif length(t) > 1
        return TreeQueryExpr(t[1], [build_tq_tree(ti) for ti in t[2:end]])
    else
        @error "Input tuple is empty."
    end
end

"""
Checks that a query tree does not contain duplicate capture keys.
"""
function check_tq_tree(tree::TreeQueryExpr)
    captures = [n for n in PreOrderDFS(tree) if ParSitter.is_capture_node(n).is_match]
    @assert length(captures) == length(unique(captures)) "Found non-unique capture keys in query"
end


"""
    build_xml_tree(tree_sitter_xml_ast::String)

Postprocesses and parse the tree-sitter XML output to
something that can be traversed to match a given query.
"""
function build_xml_tree(tree_sitter_xml_ast::String)
    tmp = replace(tree_sitter_xml_ast, "\n"=>"")
    xml = EzXML.parsexml(tmp)
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
is_capture_node(n::String; capture_sym=DEFAULT_CAPTURE_SYM) = begin
    is_match = !isnothing(match(Regex("[.]*$(capture_sym)[.]*"), n))
    capture_key = is_match ? string(split(n, capture_sym)[2]) : ""
    return (;is_match, capture_key)
end
is_capture_node(n::TreeQueryExpr; capture_sym=DEFAULT_CAPTURE_SYM) = is_capture_node(n.head; capture_sym)
is_capture_node(n; capture_sym=DEFAULT_CAPTURE_SYM) = (is_match=false, capture_key="")


"""
    function match_tree(target_tree,
                        query_tree;
                        captured_symbols=Dict(),
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
and a `Dict("capture_variable"=>captured_target_node_value))`.

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
(true, Dict{Any, Any}("v2" => 10, "v0" => 1))
(false, Dict{Any, Any}("v2" => 11))
(true, Dict{Any, Any}("v2" => 3, "v0" => 1))
```
"""
function match_tree(target_tree,
                    query_tree;
                    captured_symbols=Dict(),
                    is_capture_node=is_capture_node,
                    target_tree_nodevalue=AbstractTrees.nodevalue,
                    query_tree_nodevalue=AbstractTrees.nodevalue,
                    capture_function=AbstractTrees.nodevalue,
                    node_comparison_yields_true=(args...)->false)
    # Initializations
    c1 = children(target_tree)
    c2 = children(query_tree)
    n1 = target_tree_nodevalue(target_tree)
    n2 = query_tree_nodevalue(query_tree)
    is_capture_node_q, capture_key = is_capture_node(query_tree)
    is_capture_node_t, _ = is_capture_node(target_tree)
    # Checks whether node values match or, we have a capture node with a capture condition
    found = (n1 == n2) || node_comparison_yields_true(target_tree, query_tree)
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
        return found, captured_symbols, target_tree=>query_tree
    elseif length(c1) >= length(c2)
        if is_capture_node_q
            if is_capture_node_t
                @warn "Illegal use of a capture node in the target tree, found at node $target_tree"
            else
                found && push!(captured_symbols, capture_key => capture_function(target_tree))
            end
        end
        subtree_results = [match_tree(t, q;
                                      captured_symbols,
                                      is_capture_node,
                                      target_tree_nodevalue,
                                      query_tree_nodevalue,
                                      capture_function,
                                      node_comparison_yields_true)
                            for (t, q) in zip(c1, c2)]
        for (subtree_found, subtree_captures, _) in subtree_results
            for (k,v) in subtree_captures
                # Add a new matched string only in no value exists for the key
                # i.e. ignore multiple identical capture keys
                captured_symbols[k] = get(captured_symbols, k, v)
            end
            found &= subtree_found
        end
        return found, captured_symbols, target_tree=>query_tree
    else
        return false, captured_symbols, target_tree=>query_tree
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
6-element Vector{Tuple{Bool, Dict{Any, Any}}}:
 (1, Dict("v2" => 3, "v0" => 1))
 (0, Dict())
 (0, Dict())
 (0, Dict("v2" => 3))
 (0, Dict())
 (0, Dict())
```
"""
function query(target_tree,
               query_tree;
               is_capture_node=is_capture_node,
               target_tree_nodevalue=AbstractTrees.nodevalue,
               query_tree_nodevalue=AbstractTrees.nodevalue,
               capture_function=AbstractTrees.nodevalue,
               node_comparison_yields_true=(args...)->false)
    # Checks
    check_tq_tree(query_tree)
    matches = []
    for tn in PreOrderDFS(target_tree)
        m = match_tree(tn,
                       query_tree;
                       is_capture_node,
                       target_tree_nodevalue,
                       query_tree_nodevalue,
                       capture_function,
                       node_comparison_yields_true)
        push!(matches, m)
    end
    return matches
end
