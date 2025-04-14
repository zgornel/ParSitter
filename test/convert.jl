@testset "conversions: Tuple -> TreeQueryExpr -> Tuple" begin
    # Vector of input Tuples and outputs after two conversions: to TreeQueryExpr and Tuple
    TTS=[ (1,) => (1,),
          (1,2,3) => (1,2,3),
          (1, (2,)) => (1, (2,)),  # only child, keep (2,)
          (1, 2, (3,), 4, 5) => (1, 2, 3, 4, 5),
          ((1,2), (3,), 4, 5, (6,(7,8))) => ((1,2), 3, 4, 5, (6, (7,(8,)))),
          (1,2,(3,(4,5,(6,-6, -6),7,5))) => (1,2,(3,(4,5,(6,-6,-6),7,5)))
        ]
    for (t, t2)in TTS
        # Convert Tuple to TreeQueryExpr and test for equal trees
        tq = ParSitter.build_tq_tree(t)
        tq2 = ParSitter.build_tq_tree(t2)
        @test tq == tq2
        # Convert back to Tuple and check against verification Tuples
        tt = convert(Tuple, tq)
        @test tt==t2
    end
end
