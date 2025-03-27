using EzXML
using AbstractTrees

const DEFAULT_CAPTURE_SYM="@"

# AbstractTrees interface for tree-sitter generated XML ASTs
 _remove_space(s)=strip(replace(s, r"[\s]+"=>" "))
AbstractTrees.children(t::EzXML.Node) = collect(EzXML.eachelement(t));
#AbstractTrees.AbstractTrees.nodevalue(t::EzXML.Node) = (t.name, _remove_space(EzXML.nodecontent(t)))
AbstractTrees.nodevalue(t::EzXML.Node) = (t.name, string(t.ptr))
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
    capture_key = is_match ? string(split(n, capture_sym)[2]) : nothing
    return (;is_match, capture_key)
end
is_capture_node(n::TreeQueryExpr; capture_sym=DEFAULT_CAPTURE_SYM) = is_capture_node(n.head; capture_sym)
is_capture_node(n; capture_sym=DEFAULT_CAPTURE_SYM) = (is_match=false, capture_key=nothing)

#TODO (Corneliu): implement O(n) algorithm based on either:
#                 (1) https://www.geeksforgeeks.org/check-binary-tree-subtree-another-binary-tree-set-2/
#                 (2) https://www.geeksforgeeks.org/check-if-a-binary-tree-is-subtree-of-another-binary-tree-using-preorder-traversal-iterative/
"""
    match_tree(target_tree,
               query_tree;
               captured_symbols=Dict(),
               capture_sym=DEFAULT_CAPTURE_SYM,
               target_tree_nodevalue=AbstractTrees.nodevalue,
               query_tree_nodevalue=AbstractTrees.nodevalue,
               capture_function=AbstractTrees.nodevalue,
               node_comparison_yields_true=(args...)->false)

Function that searches a `query_tree` into a `target_tree`. It returns a vector
of subtree matches, where each element is a `Tuple` that contains the result
of the match, any captured values and the trees that were compared.
To capture a value, the `is_capture_node` must return true.
One example is using query nodes of  the form `"nodevalue@capture_variable"`.
In the matching process, the query and target node values are extracted
using `target_tree_nodevalue` and `target_tree_nodevalue` respectively and compared.
If they match, the `target_tree` node value is captured by applying `capture_function` to the node.
"""
function match_tree(target_tree,
                    query_tree;
                    captured_symbols=Dict(),
                    is_capture_node=is_capture_node,
                    target_tree_nodevalue=AbstractTrees.nodevalue,
                    query_tree_nodevalue=AbstractTrees.nodevalue,
                    capture_function=AbstractTrees.nodevalue,
                    node_comparison_yields_true=(args...)->false)
	# Checks
	check_tq_tree(query_tree)
	# Initializations
    c1 = children(target_tree)
    c2 = children(query_tree)
    n1 = target_tree_nodevalue(target_tree)
    n2 = query_tree_nodevalue(query_tree)
    # Checks whether node values match or, we have a capture node with a capture condition
    found = (n1 == n2) || node_comparison_yields_true(target_tree, query_tree)
	# Start recursion
    if length(c1) == length(c2) == 0
        if is_capture_node(query_tree).is_match
            if is_capture_node(target_tree).is_match
                @warn "Illegal use of a capture node in the target tree, found at node $target_tree"
            else
                push!(captured_symbols,
                    is_capture_node(query_tree).capture_key => capture_function(target_tree))
            end
        end
        return found, captured_symbols, target_tree => query_tree
    elseif length(c1) >= length(c2)
        if is_capture_node(query_tree).is_match
            if is_capture_node(target_tree).is_match
                @warn "Illegal use of a capture node in the target tree, found at node $target_tree"
            else
                push!(captured_symbols,
                    is_capture_node(query_tree).capture_key => capture_function(target_tree))
            end
        end
        subtree_results = map(
                            ci->match_tree(ci...;
                                           captured_symbols,
                                           is_capture_node,
                                           target_tree_nodevalue,
                                           query_tree_nodevalue,
                                           capture_function,
                                           node_comparison_yields_true),
                            Iterators.take(zip(c1, c2), length(c2)))
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
    Query a tree with another tree. Both trees should support
    the `AbstractTrees` interface.
"""
function query(target_tree,
               query_tree;
               is_capture_node=is_capture_node,
               target_tree_nodevalue=AbstractTrees.nodevalue,
               query_tree_nodevalue=AbstractTrees.nodevalue,
               capture_function=AbstractTrees.nodevalue,
               node_comparison_yields_true=(args...)->false)
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
