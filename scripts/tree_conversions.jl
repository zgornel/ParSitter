using AbstractTrees
using ParSitter
_R_code = (ParSitter.Code("""
	mod13 <- glmmTMB(var1 ~ var2 + var3 +
                          var4 + var5 +
                          (1 | var6),
                    data = some_table,
                    family = binomial(link = "logit"))
      """), "r")
#_parsed = ParSitter.parse(_PYTHON...)
#_parsed = ParSitter.parse(_C...)
_parsed = ParSitter.parse(_R_code...)
tt = ParSitter.build_xml_tree(_parsed[""])
ttc = convert(ParSitter.TreeQueryExpr, tt.root; nodevalue=n->n.name)
ttc |> print_tree
convert(Tuple, ttc) |> println
