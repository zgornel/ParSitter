using EzXML

using AbstractTrees
AbstractTrees.children(t::EzXML.Node) = collect(EzXML.eachelement(t));
_remove_space(s)=strip(replace(s, r"[\s]+"=>" "))
AbstractTrees.nodevalue(t::EzXML.Node) = (t.name, _remove_space(EzXML.nodecontent(t)))

# Postprocesses an XML to something that can be traversed
# to match a given query
function build_tree(parsed)
   # Parse XML and print interesting information
   xml = EzXML.parsexml(replace(parsed, "\n"=>""))
end
