require '../generator/Alphabeth.rb'
require "rexml/document"
include REXML

filePath=ARGV[0]
raise ArgumentError.new("Usage: ruby graphML2xml.rb path_to_graphml file") if filePath==nil
fileExtension=File.extname(filePath).downcase
raise ArgumentError.new("File #{filePath} not found") if not File.exist?(filePath)
raise ArgumentError.new("Only graphml files are supported") if not fileExtension==".graphml"
xmlEncodedGraph=File.open(filePath)

doc=Document.new xmlEncodedGraph
out=Document.new
out.add_element("fsm")
root=out.root

XPath.each(doc, "//key[@attr.name='description' and @for='node']"){|node_desc_key| @nDescKey=node_desc_key.attributes["id"]}
XPath.each(doc, "//key[@attr.name='description' and @for='edge']"){|edge_desc_key| @eDescKey=edge_desc_key.attributes["id"]}				

XPath.each(doc, "//node"){|node|					
	id=node.attributes["id"]
	XPath.each(doc, "//node[@id=#{"'"+id.to_s+"'"}]/data/y:ShapeNode/y:NodeLabel"){|l| @node_name=l.text}
	XPath.each(doc, "//node[@id=#{"'"+id.to_s+"'"}]/data[@key=#{"'"+@nDescKey.to_s+"'"}]"){|d| @node_inputs=d.text}
	XPath.each(doc, "//node[@id=#{"'"+id.to_s+"'"}]/data/y:ShapeNode/y:Shape"){|f| @node_form=f.attributes["type"]}
	# <y:Shape type="ellipse"/>
	#write staff
	state=Element.new("state")
	state.attributes["id"]=id
	state.attributes["name"]=@node_name
	state.attributes["description"]=nil # no description for graphML node
	state.attributes["inputs"]=@node_inputs
	state.attributes["main"]=(@node_form=='ellipse') ? 'true' : 'false'
	root.add_element(state)
	@node_name,@node_inputs=nil,nil
}
XPath.each(doc, "//edge"){|edge|
	id=edge.attributes["id"]
	source=edge.attributes["source"]
	target=edge.attributes["target"]
	XPath.each(doc, "//edge[@id=#{"'"+id.to_s+"'"}]/data/y:PolyLineEdge/y:EdgeLabel"){|l| @edge_label=l.text}
	XPath.each(doc, "//edge[@id=#{"'"+id.to_s+"'"}]/data[@key=#{"'"+@eDescKey.to_s+"'"}]"){|d| @edge_desc=d.text}
	#write stuff
	transition=Element.new("transition")
	transition.attributes["id"]=id
	transition.attributes["source"]=source
	transition.attributes["target"]=target
	transition.attributes["description"]=@edge_desc
	# need to parse edge label to exctract NAME, [condition], /action/, {internal_state}
	if @edge_label=~/^([^\[\{\/]+)[\[\{\/]?.*$/		
		name=$1
		transition.attributes["name"]=name.strip
	end
	condition=@edge_label.scan(/\[.+\]/).first
	transition.attributes["condition"]=condition.delete('[').delete(']').strip if not condition==nil
	action=@edge_label.scan(/\/.+\//).first
	transition.attributes["action"]=action.delete('/').strip if not action==nil
	internal_state=@edge_label.scan(/\{.+\}/).first
	transition.attributes["internalState"]=internal_state.delete('{').delete('}').strip if not internal_state==nil
	chance=@edge_label.scan(/\<.+\>/).first
	transition.attributes["chance"]=chance.delete('<').delete('>').strip if not chance==nil
	type=@edge_label.scan(/\\.+\\/).first
	if not (type==nil or Alphabeth::TYPES.include?(type))
		transition.attributes["type"]=type.delete('\\').delete('\\').strip 
	else
		transition.attributes["type"]=Alphabeth.default 
	end
	root.add_element(transition)
	@edge_name,@edge_desc=nil,nil
}

#make model.xml and write doc to it
modelXml=File.open("_out_/model.xml","w+")
out.write(modelXml,4)
modelXml.close
