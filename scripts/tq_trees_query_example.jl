# Run this script with `julia --project ./scripts/tq_trees_query_example.jl`
using AbstractTrees
using Revise
using ParSitter
target = (1, 2, 3, (4, 2, 6, (1, 2, 1)), ("@v0", 2, "@v2"))
query = ("@v0", "2", "@v2")
query_tq = ParSitter.build_tq_tree(query)
target_tq = ParSitter.build_tq_tree(target)

_query_nodevalue(n) = ParSitter.is_capture_node(n).is_match ? split(n.head, "@")[1] : n.head

_capture_on_empty_query_value(t1,t2) = ParSitter.is_capture_node(t2).is_match && isempty(_query_nodevalue(t2))

@time r=ParSitter.query(target_tq,
                        query_tq;
                        target_tree_nodevalue=n->string(n.head),
                        query_tree_nodevalue=_query_nodevalue,
                        capture_function=n->n.head,
                        node_comparison_yields_true=_capture_on_empty_query_value);
r_true = filter(t->t[1], r)
@show r_true[1][1:2]
