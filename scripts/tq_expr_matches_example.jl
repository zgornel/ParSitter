# Example of partial matches between query and target:
# returned found trees are larger than query
using AbstractTrees
using ParSitter
target = (1, (0,0), (2,(2,2),2,0), (1,1))
query = ("@2",("@3","@4"))
query_tq = ParSitter.build_tq_tree(query)
target_tq = ParSitter.build_tq_tree(target)
r=ParSitter.query(target_tq, query_tq)
for _r in r
    if (first(_r))
        print_tree(_r[3][1]);
        print("Match: $(_r[1]) ")
        println(_r[2])
        println("-----------")
    end
end
