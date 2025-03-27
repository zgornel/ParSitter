# Define utiliy function for the types of trees and node captures used
_capture_function(target_node) = target_node.head

_target_tree_nodevalue(target_node) = string(target_node.head)

_query_tree_nodevalue(query_node) =
    ParSitter.is_capture_node(query_node).is_match ? split(query_node.head, "@")[1] : query_node.head

# Functions that will always capture when reaching query nodes of the form: "@query_key"
_capture_on_empty_query_value(tree1, tree2) =
    ParSitter.is_capture_node(tree2; capture_sym="@").is_match && isempty(_query_tree_nodevalue(tree2))

@testset "simple quering" begin
    @testset "case 1" begin
        target = ParSitter.build_tq_tree(
                        (1,2)
                    )
        query = ParSitter.build_tq_tree(
                        (1,2)
                    )
        results = ParSitter.query(target, query)
        @test sum(first, results) == 1
        @test sum(p->!isempty(p[2]), results) == 0
    end
	@testset "case 2" begin
        target = ParSitter.build_tq_tree(
                        (1,2)
                    )
        query = ParSitter.build_tq_tree(
                        ("@v1", "@v2")
                    )
        results = ParSitter.query(target,
                                  query;
                                  target_tree_nodevalue=_target_tree_nodevalue,
                                  query_tree_nodevalue=_query_tree_nodevalue,
                                  capture_function=_capture_function,
                                  node_comparison_yields_true=_capture_on_empty_query_value)
        @test sum(first, results)==1
        for (is_match, captures) in results
            if is_match
                @test get(captures, "v1", -1) == 1
                @test get(captures, "v2", -1) == 2
                @test length(keys(captures)) == 2
            end
        end
    end
	@testset "case 3" begin
        target = ParSitter.build_tq_tree(
                        (1, (2,3, "3a"), (4,5), 6)
                    )
        query = ParSitter.build_tq_tree(
                        ("@v0", ("2", "@v2", "3a"))
                    )
        results = ParSitter.query(target,
                                  query;
                                  target_tree_nodevalue=_target_tree_nodevalue,
                                  query_tree_nodevalue=_query_tree_nodevalue,
                                  capture_function=_capture_function,
                                  node_comparison_yields_true=_capture_on_empty_query_value)
        @test any(first, results)
        for (is_match, captures) in results
            if is_match
                @test get(captures, "v0", -1) == 1
                @test get(captures, "v2", -1) == 3
                @test length(keys(captures)) == 2
            end
        end
    end
    @testset "case 4" begin
        target = ParSitter.build_tq_tree(
                        (1, (2,3), (2, (2,3)))
                    )
        query = ParSitter.build_tq_tree(
                        (2,3)
                    )
        results = ParSitter.query(target, query)
        @test sum(first, results) == 2
        @test sum(p->!isempty(p[2]), results) == 0  # no captured values
    end
	@testset "case 5" begin
        target = ParSitter.build_tq_tree(
                        (1, 2, 3, (4,2,6, (1,2,1)), ("@v0", 2, "@v2"))
                    )
        query = ParSitter.build_tq_tree(
                        ("@v0", "2", "@v2")
                    )
        results = ParSitter.query(target,
                                  query;
                                  target_tree_nodevalue=_target_tree_nodevalue,
                                  query_tree_nodevalue=_query_tree_nodevalue,
                                  capture_function=_capture_function,
                                  node_comparison_yields_true=_capture_on_empty_query_value)
        @test sum(first, results) == 4
        @test sum(p->!isempty(p[2]), results) == 3
        expected_captures = [
            Dict{Any, Any}("v2" => 3, "v0" => 1),
            Dict{Any, Any}("v2" => 6, "v0" => 4),
            Dict{Any, Any}("v2" => 1, "v0" => 1),
            Dict()]
        for (is_match, captures) in results
            if is_match
                @test captures in expected_captures
            end
        end
    end
end

@testset "code quering" begin
    # TODO(Corneliu): Implement tests
	@testset "function call" begin
		@test true
	end

	@testset "parameters" begin
	    @test true	
	end

	@testset "edge cases..." begin
        @test true
	end
end

