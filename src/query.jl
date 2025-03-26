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
	captures = [n.head for n in PreOrderDFS(tree) if ParSitter.is_match_node(n.head)]
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


# Function that checks whether a node is a 'capture node' i.e. value of the form "@capture_key"
is_match_node(n; capture_sym=DEFAULT_CAPTURE_SYM) = isa(n, String) ? startswith(n, capture_sym) : false
# Function to get the capture key
capture_key(n; capture_sym=DEFAULT_CAPTURE_SYM) = is_match_node(n; capture_sym) ? split(n, capture_sym)[2] : ""


#TODO (Corneliu): implement O(n) algorithm based on either:
#                 (1) https://www.geeksforgeeks.org/check-binary-tree-subtree-another-binary-tree-set-2/
#                 (2) https://www.geeksforgeeks.org/check-if-a-binary-tree-is-subtree-of-another-binary-tree-using-preorder-traversal-iterative/
"""
    match_tree(tree1, tree2; captured_symbols=Dict(), capture_sym="@")

Function that searches a query tree `tree2` into a target tree `tree1`.
It returns a vector of potential matches, where each element is a `Tuple{Bool, Dict}`
containing the result of the match and any captured strings. To capture a value,
the query node must start with `"@"`.
```
using ParSitter
       target = (1, 1, (1, (1,(2,-3))), 1, (-1,-2,-3,-4))
       query = ("@0",("@1",-3))
       query_tq = ParSitter.build_tq_tree(query)
       target_tq = ParSitter.build_tq_tree(target)
       ParSitter.match_tree(target_tq.children[2].children[1], query_tq)
(true, Dict{Any, Any}("1" => 2, "0" => 1))
```
"""
function match_tree(tree1,
                    tree2;
                    captured_symbols=Dict(),
                    capture_sym=DEFAULT_CAPTURE_SYM)
	# Checks
	check_tq_tree(tree2)
	# Initializations
    c1 = children(tree1)
    c2 = children(tree2)
    n1 = AbstractTrees.nodevalue(tree1)
    n2 = AbstractTrees.nodevalue(tree2)
	# Start recursion
    if length(c1) == length(c2) == 0
        if n1 == n2
            is_match_node(n1) && @warn "Value $n1 will not be captured, illegal use of '@'"
            return true, captured_symbols, tree1 => tree2
        elseif is_match_node(n2)
            push!(captured_symbols, capture_key(n2)=>n1)
            return true, captured_symbols, tree1 => tree2
        else
            return false, captured_symbols, tree1 => tree2
        end
    elseif length(c1) >= length(c2) && length(c2) > 0
        found = (n1 == n2) || is_match_node(n2)
        if is_match_node(n2)
            if is_match_node(n1)
                @warn "Value $n1 will not be captured, illegal use of '@'"
            else
                push!(captured_symbols, capture_key(n2) => n1)
            end
        end
        subtree_results = map(
            ci->match_tree(ci...; captured_symbols),
            Iterators.take(zip(c1, c2), length(c2))
           )
        for (subtree_found, subtree_captures) in subtree_results
            for (k,v) in subtree_captures
                # Add a new matched string only in no value exists for the key
                # i.e. ignore multiple identical capture keys
                captured_symbols[k] = get(captured_symbols, k, v)
            end
            found &= subtree_found
        end
        return found, captured_symbols, tree1=>tree2
    else # query has more children
        return false, captured_symbols, tree1=>tree2
    end
end


"""
    Query a tree with another tree. Both trees should support
    the `AbstractTrees` interface.
"""
function query(target_tree, query_tree)
    matches = []
    for tn in PreOrderDFS(target_tree)
        push!(matches, match_tree(tn, query_tree))
    end
    return matches
end
