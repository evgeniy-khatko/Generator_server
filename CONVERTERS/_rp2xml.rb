require "rexml/document"
include REXML
require 'logger'
require 'bin/Axure.Document'
require 'bin/types.voc.rb'
require 'bin/regexp.voc.rb'
require File.dirname(__FILE__)+'../generator/TestInfo.rb'
include Axure
include System
include System::Collections::Generic
include Axure::Document

MAX_WIDGET_NAME_LENGTH=15
VARIOUS = 'VARIOUS'
DETERMINISTIC = 'DETERMINISTIC'
EXPECTED = 'EXPECTED'

class RP
	attr_reader :id,:parent_id,:type
	attr_accessor :name

	def initialize(id,parent_id,type,name='')
		@id=id
		@parent_id=parent_id
		@type=type
		@name=name
		self.class.add(self)
	end

private
	@objects=[]

	def self.fnd(query_hash)
		# similar to rails find method
		# 1. validate input query hash
		return [] if all.empty?
		query_hash.each_key{|k| raise "#{inspect}::fnd(#{query_hash.inspect}) wrong #{inspect} attribute #{"@"+k}\nAvailable attributes: #{all.first.instance_variables}" if not all.first.instance_variable_defined?("@"+k)}

		# 2. iterate through all items and find suitable
		found=[]
		all.each{|item|
			bingo=true
			query_hash.each{|attribute,value| bingo=false if item.instance_variable_get("@"+attribute)!=value}
			found << item if bingo
		}
		return found
	end		

	def self.add(obj)
		@objects.push(obj)
	end

	def self.all
		return @objects
	end
end

class Case
  attr_reader :description,:interactions,:parent
  #OnClick:
  #	Case 1 (If visibility of panel Menus&Dialogs equals false): <-- case description
  #		Open Home in Current Window <-- case interaction
  #		App -> close <-- case interaction 
  #	Case 2 (Else If True):
  #		Hide Menus&Dialogs
  def initialize(case_desc,parent)
    @description=case_desc
    @interactions=[]
    @parent=parent
  end

  def add_interaction(inter_desc)
    @interactions.push(inter_desc)
  end
end

class Page < RP
	attr_accessor :main, :cases
	def initialize(id,parent_id,type,name,main)
		super(id,parent_id,type,name)
		@main=main
    @cases = []
    @active_elements = []
	end
  
	def add_active_element(obj)
		@active_elements.push(obj)
	end

	def active_elements
		return ActiveElement.fnd({:parent_id=>self.id})
	end

	def add_case(obj)
		@cases.push(obj)
	end

private
	@objects=[]
end

class ActiveElement < RP
	attr_accessor :cases
	def initialize(id,parent_id,name)
		super(id,parent_id,'ActiveElement',name)
		@cases=[]
	end

	def add_case(obj)
		@cases.push(obj)
	end

	def parent
		parents=Page.fnd({:id=>self.parent_id})
		raise "ActiveElement #{self.name}(#{self.id}) has more then 1 parent: #{parents.collect{|p| p.name}.join(',')}" if parents.length>1
		return parents.first
	end

	
private
	@objects=[]
end

class DynamicArea < RP
	attr_accessor :pages, :visible
	def initialize(id,parent_id,type,name,visible)
		super(id,parent_id,type,name)
		@pages=[]
		@visible=visible
	end	


	def add_page(obj)
		@pages.push(obj)
	end
private
	@objects=[]
end

model_path=ARGV[0].to_s
raise "file '#{model_path}' not found" if not File.exists?(model_path)
@doc=RPDocument.Load(model_path)
logfile=File.new('rp2xml.log','w+')
$log=Logger.new(logfile)
$log.formatter = proc { |severity, datetime, progname, msg|
 	"#{msg}\n"
}
$log.level = Logger::DEBUG

@xml=REXML::Document.new
@xml.add_element("fsm")

# finds all pages of the application using BFS algorithm
# used in get_pages method to extract pages from rp document
def bfs_through_wireframe(treeNode,pages)
	pages << treeNode if not pages.include?(treeNode)
	children=treeNode.ChildNodes.ToArray
	children.each{|child|
		pages << child
	}

	children.each{|child|
		bfs_through_wireframe(child,pages)
	}
end

# extract all pages from rp document
# returns the array of page objects
def pages(document)
	pageNodes=[]
	document.Sitemap.RootNodes.ToArray.each{|rootNode|	
		bfs_through_wireframe(rootNode,pageNodes)
	}
	
	pages=[]
	pageNodes.each{|pageNode|
		pageHandle=pageNode.NodeValue
		page=document.LoadPackage(pageHandle)
		pages << page
	}	
	return pages
end


def get_name(widget)
	if TXT_WDG.include?(widget.GetType.to_s) and widget.Text!=nil and widget.Text!='' and widget.Text.length < MAX_WIDGET_NAME_LENGTH
		return widget.Text.gsub("\n",'').strip
	elsif widget.HasChildren
		widget.Widgets.ToArray.each{|sw| 
			name=get_name(sw)
			return name if name!=nil and name!='' and name.length < MAX_WIDGET_NAME_LENGTH
		}
	end
	return widget.Name
end

def get_velements(page)
  if page.HasInteraction 
    page.Interaction.Events.ToArray.each{|event|
      if event.EventName=='OnPageLoad' and event.EventDescription!=nil
        events=event.EventDescription.split("\n") 
        events.shift # removing 'OnLoad:'
        current_eq_class = nil
        events.each{|line|
          if CASE_LINE===line
            current_eq_class = $1
          elsif INPUT===line
            velement = TestInfo.new($1 + page.GetHashCode.to_s, page.GetHashCode)
            TestInfo.objects.delete_if{ |el| el.parent_id == page.GetHashCode and TestInfo::EXPECTED.include?(el.action) }
            velement.locator = $1
            velement.action = TestInfo::ENTER
            velement.data = $2            
            velement.eq_class = current_eq_class
          elsif SELECT===line
            velement = TestInfo.new($1 + page.GetHashCode.to_s, page.GetHashCode)
            velement.locator = $1
            velement.action = TestInfo::SELECT
            velement.data = $2            
            velement.eq_class = current_eq_class
          elsif CHECK===line
            velement = TestInfo.new($1 + page.GetHashCode.to_s, page.GetHashCode)
            velement.locator = $1
            velement.action = TestInfo::CHECK
            velement.data = $2            
            velement.eq_class = current_eq_class
          else
            raise "unknown input type on page #{page.PackageName}, case: #{line}"
          end
          if TRANSITION_INTERNAL === line
            velement.internal_check = $1
          end
        } 
      end #if
    }		
  end
end

def get_active_elements(widgets,wid_container)
	# inputs: 
	# 1. widgets array - typically widgets on the page or dynamic panel state
	# 2. instance of the ruby Page class. It's used to store widgets info in suitable form
	# workflow: widgets (RP widgets) -> info -> wid_container (Page class instance)
	widgets.each{|w|
		if w.HasInteraction and w.GetType.to_s!=DP # active active_element or area on the screen
			name=get_name(w)
			raise "Bad name for #{w.id} footnote #{w.FootnoteNumber}, on page #{wid_container.name}\nName must be '' < name < 15 symb" if name==nil
			but=ActiveElement.new(w.GetHashCode,wid_container.id,name) 
      delement = TestInfo.new(w.GetHashCode,wid_container.id)
      delement.locator = name
			w.Interaction.Events.ToArray.each{|event|
				if event.EventName=='OnClick' and event.EventDescription!=nil
					events=event.EventDescription.split("\n") 
					# parse events

					#OnClick:
					#	Case 1 (If visibility of panel Menus&Dialogs equals false):
					#		Open Home in Current Window
					#		App -> close
					#	Case 2 (Else If True):
					#		Hide Menus&Dialogs
					events.shift # removing 'OnClick:'
					events.each{|line|
						if CASE_LINE===line
							@c=Case.new($1,but)
							but.add_case(@c)
              if TRANSITION_TYPE === line
                raise "UNKNOWN USER ACTION #{$1.strip} on page #{wid_container.name}, case #{line}" unless TestInfo::DETERMINISTIC.include? $1.strip 
                delement.action = $1.strip
              else
                delement.action = TestInfo::DEFAULT
                puts "Default user action was set on page #{wid_container.name} for case #{line}"
              end
              if TRANSITION_INTERNAL === line
                delement.internal_check = $1.strip
              end
						elsif INTERACTION_LINE===line
							@c.add_interaction($1)
						end

					} 
				end #if
			}		
			wid_container.add_active_element(but) 
		elsif w.GetType.to_s==DP # dynamic area
			da=DynamicArea.new(w.GetHashCode,wid_container.id,w.GetType.to_s,w.Name,w.IsVisible)	
			w.PanelStates.ToArray.each{|ps|
				da_page=Page.new(ps.GetHashCode,da.id,ps.GetType.to_s,ps.DiagramName,false) 
				da.add_page(da_page)	
				get_active_elements(ps.Widgets.ToArray,da_page)
			}
    else # any other non various widget
      if get_name(w) =~ /[a-zA-z]+/ 
        ee = TestInfo.new(w.GetHashCode,wid_container.id)
        ee.locator = get_name(w)
        ee.action = TestInfo::EXIST
      end
    end
	}
end

def load_model
	# workflow: iterate through all pages and create instances of Page, Dynamic Area, ActiveElement classes. 
	# Prepare info for future use
	$log.info 'Load model'
	pages(@doc).each do |page| 
		p=Page.new(page.GetHashCode,nil,page.GetType.to_s,page.PackageName,true)	
		# get deterministic and various elements from RPPage		
		get_active_elements(page.Diagram.Widgets.ToArray,p)
		get_velements(page)
	end
end

def generate_xml
	# get prepared ruby classes instances and work with them to store info to XML document
	$log.debug 'generate_xml'
	
	# generate states from pages (pages are RPPages+RPDynamicPanel_states)
	#	
	Page.all.each{|page|
		gen_state(@xml,page.id,page.name,page.type,page.type==PAGE, TestInfo.fnd_by_parent(page.id))
	}

	# generate transitions
	#
	Page.all.each{|page|
		if page.active_elements.empty?			
			if page.main
				message="Separated page found: #{page.name}(#{page.id})"	
			else
				da=DynamicArea.fnd({:id=>page.parent_id}).first 
				main_page=Page.fnd({:id=>da.parent_id}).first
				message="Separated page found: #{main_page.name}(#{page.name})(#{page.id})"
			end
			$log.info message
			next
		end
		$log.debug page.name.upcase
		page.active_elements.each{|active_element|
			$log.debug "\t"+active_element.name
			# MAIN PROCEDURE
			# need to find active_element's target(s), parsing the cases descriptions
			# each case is potential transition of the resulting FSM
			raise "ActiveElement #{active_element.name} on Page #{page.name} has no cases - internal error" if active_element.cases.empty? 
			active_element.cases.each{|c|
				$log.debug "\t\t"+c.description
				# parse_case(case) => returns array [parent_page_id(s),target_page_id,transition_condition,transition_action,transition_internal_state]
				parse_results=parse_case(c)
				chance=parse_results.pop
				action=parse_results.pop
				condition=parse_results.pop
				target_page_id=parse_results.pop
				descr=(TRANSITION_CONDITION===c.description or TRANSITION_ACTION===c.description or TRANSITION_INTERNAL===c.description or TRANSITION_CHANCE===c.description or TRANSITION_CASE===c.description)? '' : " - #{c.description}"
				raise "Cant find target State on Page #{page.name} through ActiveElement #{active_element.name}, Case #{c.description}" if target_page_id==nil
				raise "Cant find source State on Page #{page.name} through ActiveElement #{active_element.name}, Case #{c.description}" if parse_results.empty?
				parse_results.each{|source_page_id|
					gen_transition(@xml,"#{source_page_id}-#{target_page_id}",active_element.name+descr,source_page_id,target_page_id,condition,action,chance,TestInfo.fnd_by_id(active_element.id))
				}
			}			
		}
	}
	# merge states with visible dynamic areas
	$log.info "Merge states"
	DynamicArea.fnd({:visible=>true}).each{|area|
		master=Page.fnd({:id=>area.parent_id}).first
		slave=area.pages.first
		merge_elements(@xml,master.id,slave.id)
	}
	modelXml=File.open('_out_/model.xml',"w+")
	@xml.write(modelXml,4)
	modelXml.close	
end

def parse_case(c)
	results=[]
	# find target
	last_i=c.interactions.last	
	raise "When finding parent for active_element #{c.parent.name} got results: #{Page.fnd({:id=>c.parent.parent_id})}" if Page.fnd({:id=>c.parent.parent_id}).length!=1 
	parent_page=Page.fnd({:id=>c.parent.parent_id}).first # c.parent <-- parent active_element object
	main_parent_page=parent_page
	if not parent_page.main
		da=DynamicArea.fnd({:id=>parent_page.parent_id}).first
		main_parent_page=Page.fnd({:id=>da.parent_id}).first
	end

	# so parent_page is always main page

	c.interactions.each{|i|
		location="On page=#{main_parent_page.name}(#{parent_page.name}), active_element=#{c.parent.name}, case=#{c.description}, interaction=#{i}"
		if i.match(',')==nil
			case
				when WAIT===i 
					if i==last_i
						results.push(parent_page.id,parent_page.id)
						break
					else
						next
					end
				when (SET_TEXT===i or SET_IS_CHECKED===i or SET_SELECTED_OPT===i or SET_VAR_VAL===i)
					if i==last_i
						results.push(parent_page.id,parent_page.id)
						break
					else
						next
					end	
				when OPEN_LINK_IN===i
					pages=Page.fnd({:name=>$1,:main=>true}) 
					if pages.length!=1
						raise "#{location}-->result of parsing OPEN_LINK_IN, #{$1}. Found not 1 page: #{pages}"
					else
						results.push(parent_page.id,pages.first.id)
						break # leave cycle, not interested in the rest interactions
					end
				when CLOSE_CUR_W===i
					if i==last_i
						$log.info "CLOSE CUR WINDOW found on page #{parent_page.name}, active_element=#{c.parent.name},case=#{c.description} --> returning parent_page: #{parent_page.name}"
						#results.push(main_parent_page.id)
						raise "Close current window is not supported."
						break
					else
						next
					end
				when SET_P_STATE===i
					da=DynamicArea.fnd({:name=>$1,:parent_id=>main_parent_page.id}).first
					pages=Page.fnd({:name=>$2,:parent_id=>da.id})
					if pages.length!=1
						raise "#{location}-->result of parsing SET_P_STATE, #{$2}. Found not 1 page: #{pages}"
					else
						results.push(parent_page.id,pages.first.id)	
						break
					end
				when SHOW_PANEL===i
					areas=DynamicArea.fnd({:name=>$1,:parent_id=>main_parent_page.id}) 
					if areas.length!=1
						raise "#{location}-->result of parsing SHOW_PANEL, #{$1}. Found not 1 Dynamic panel: #{areas}"	
					else
						$log.info"#{location}-->result of parsing SHOW_PANEL, #{$1}. Assumin there is no Hide THIS panel interaction in this case --> returning first state of the panel" 
						results.push(parent_page.id,areas.first.pages.first.id)	# default page of the dynamic area - first one
						break # assuming that there is no Hide THIS panel interaction in the current case. Otherwise this is illogical case.
					end
				when HIDE_PANEL===i
					areas=DynamicArea.fnd({:name=>$1,:parent_id=>main_parent_page.id}) 	
					if areas.length!=1
						raise "#{location}-->result of parsing HIDE_PANEL, #{$1}. Found not 1 Dynamic panel: #{areas}"	
					else
						da_pages=Page.fnd({:parent_id=>areas.first.id})
						if da_pages.include?(parent_page) # trying to hide SELF
							results.push(parent_page.id,main_parent_page.id)
						else # for sure it's a active_element on the main_parent_page. Assuming that the page that is being hidden in the foreground now
							da_pages.each{|dlg|
								results.push(dlg.id)
							}							
							results.push(parent_page.id)
						end
						break
					end
				when TOGGLE_VISIBILITY===i
#					areas=DynamicArea.fnd({:name=>$1,:parent_id=>main_parent_page.id}) 
#					if areas.length!=1
#						raise "#{location}-->result of parsing TOGGLE_VISIBILITY, #{$1}. Found not 1 Dynamic panel: #{areas}"	
#					else
#						area=areas.first
#						if area.visible
#							if area.name==parent_page.name
#								results.push(main_parent_page.id)
#							else
#								results.push(parent_page.id)
#							end
#						else
#							results.push(area.pages.first.id)
#						end
#						break
#					end			
					raise "#{location} Toggle visibility not supported, please use 'Show/Hided' panels instead" 
				when BRING_TO_FRONT_PANEL===i
					areas=DynamicArea.fnd({:name=>$1,:parent_id=>main_parent_page.id}) 
					if areas.length!=1
						raise "#{location}-->result of parsing BRING_TO_FRONT_PANEL, #{$1}. Found not 1 Dynamic panel: #{areas}"	
					else
						area=areas.first
						if area.visible
							results.push(parent_page.id,area.pages.first.id)
							break
						else
							results.push(parent_page.id)
							break
						end
					end	
				when (SCROLL_TO===i or ENABLE_W===i or DISABLE_W===i or SET_TO_SELECTED===i or SET_TO_DEFAULT===i or SET_FOCUS===i or EXPAND===i or COLLAPSE===i)
					results.push(parent_page.id,parent_page.id)
					break
				else			
					$log.info "#{location}. Cant find appropriate Regexp --> this must be an 'Other' interaction --> return parent_page #{parent_page.name}"	
					results.push(parent_page.id,parent_page.id)
					break
			end
		else
			case
				when SET_P_STATES===i
					raise "#{location} - Set multiple panels to states not supported. Please remove this unambiguity"
				when SHOW_PANEL===i
					panel_names=($1.split(',').collect{|p| p.strip})
					last_invisible=nil
					panel_names.each{|name|
						areas=DynamicArea.fnd({:name=>name,:parent_id=>main_parent_page.id})
						raise "#{location} result of parsing - not 1 Dynamic panel: #{areas}" if areas.length!=1
						last_invisible=areas.first if not areas.first.visible
					}
					if last_invisible!=nil
						results.push(parent_page.id,last_invisible.pages.first.id)
						break
					else
						results.push(parent_page.id,parent_page.id)
						break
					end
				when HIDE_PANEL===i
					panel_names=($1.split(',').collect{|p| p.strip})	
					areas=[]
					panel_names.each{|panel_name|
						areas+=DynamicArea.fnd({:parent_id=>main_parent_page.id,:name=>panel_name})	
					}
					dlgs=[]
					areas.each{|area| 
						dlgs+=Page.fnd({:parent_id=>area.id})
					}
					dlgs.each{|dlg| results.push(dlg.id)}
					results.push(main_parent_page.id)
					break
				when TOGGLE_VISIBILITY===i
					raise "#{location} Toggle visibility not supported, please use 'Show/Hided' panels instead" 
#					panel_names=($1.split(',').collect{|p| p.strip})
#					last_panel=nil
#					panel_names.each{|name|
#						if DynamicArea.fnd({:name=>name,:parent_id=>main_parent_page.id}).length!=1
#							raise "#{location} when search for panel #{name}. Found not 1 panel" 
#						else
#							area=DynamicArea.fnd({:name=>name,:parent_id=>main_parent_page.id}).first
#							last_panel=area	if not area.visible	
#						end
#					}
#					if last_panel!=nil
#						results.push(last_panel.pages.first.id) 
#					else
#						results.push(parent_page.id)
#					end
#					break
				when (MOVE_PANEL===i or SET_TO_SELECTED===i)
					if i==last_i
						results.push(parent_page.id,parent_page.id)
					else
						next
					end
				when BRING_TO_FRONT_PANEL===i
					panel_names=($1.split(',').collect{|p| p.strip})
					top_visible_panel=nil
					panel_names.each{|name|
						if DynamicArea.fnd({:name=>name,:parent_id=>main_parent_page.id}).length!=1
							raise "#{location} when search for panel #{name}. Found not 1 panel" 
						else
							area=DynamicArea.fnd({:name=>name,:parent_id=>main_parent_page.id}).first
							top_visible_panel=area	if area.visible	
						end
					}
					if top_visible_panel!=nil
						results.push(parent_page.id,top_visible_panel.pages.first.id) 
					else
						results.push(parent_page.id,parent_page.id)
					end
					break					
				else
					$log.info "#{location}. Cant find appropriate Regexp --> this must be an 'Other' interaction --> return parent_page #{parent_page.name}"	
					results.push(parent_page.id,parent_page.id)
					break
			end				
		end
	}

	if TRANSITION_CONDITION===c.description
		results.push($1) 
	else
		results.push(nil)
	end

	if TRANSITION_ACTION===c.description
		results.push($1) 
	else
		results.push(nil)
	end

	if TRANSITION_CHANCE===c.description
		results.push($1) 
	else
		results.push(nil)
	end

	return results	
end

def debug_info
	pages(@doc).each  do |page|
		$log.debug '===PAGE==='
		$log.debug page.PackageName
		$log.debug page.GetType.to_s
		page.Diagram.Widgets.ToArray.each do |w|
			$log.debug "\t===WIDGET==="
			$log.debug "\t.Name: "+w.Name
			$log.debug "\tName: "+get_name(w).to_s
			$log.debug "\tType: "+w.GetType.to_s
			$log.debug "\tAnnotation: #{w.Annotation}" if w.IsAnnotated
			if w.HasInteraction
				$log.debug "\tInteractions:"
				w.Interaction.Events.ToArray.each do |e|
					$log.debug "\t\t===EVENT==="
					$log.debug "\t"+"\tEventType: "+e.EventType.to_s
					$log.debug "\t"+"\tEventName: "+e.EventName
					$log.debug "\t"+"\tEventDesc: "+e.EventDescription
				end
			end
		end
	end
end

def debug_info2
	$log.debug "PAGES"
	Page.all.each{|p| 
		$log.debug "#{p.id}\t#{p.name}\t#{p.parent_id}"
	}
	$log.debug "DELEMENTS"
	ActiveElement.all.each{|b|
		$log.debug "#{b.id}\t#{b.name}\t#{b.parent_id}"	
		$log.debug "\t DELEMENT CASES"
		b.cases.each{|c| $log.debug "\t\t#{c.description}\n#{c.interactions.join("\n")}"}
	}
	$log.debug "DYNAREAS"
	DynamicArea.all.each{|da| 
		$log.debug "#{da.id}\t#{da.name}\t#{da.parent_id}"
	}
end


############################# XML generator related functons #############################
def gen_state(xml_document,id,node_name,description,node_is_main,elements)
	state=Element.new("state")
	state.attributes["id"]=id
	state.attributes["name"]=node_name
	state.attributes["description"]=description
	state.attributes["main"]=node_is_main
  elements.each{ |e| 
    ee = Element.new("test_info")
    ee.attributes["locator"] = e.locator
    ee.attributes["action"] = e.action
    ee.attributes["eq_class"] = e.eq_class
    ee.attributes["data"] = e.data
    ee.attributes["index"] = e.index
    ee.attributes["internal_check"] = e.internal_check
    state.add_element(ee)
  }
	xml_document.root.add_element(state)	
end

def gen_transition(xml_document,id,edge_name,sou,tar,condition,action,chance,elements)
	transition=Element.new("transition")
	transition.attributes["id"]=id
	transition.attributes["name"]=edge_name
	transition.attributes["source"]=sou
	transition.attributes["target"]=tar
	transition.attributes["condition"]=condition
	transition.attributes["action"]=action
	transition.attributes["chance"]=chance
  elements.each{ |e| 
    ee = Element.new("test_info")
    ee.attributes["locator"] = e.locator
    ee.attributes["action"] = e.action
    ee.attributes["eq_class"] = e.eq_class
    ee.attributes["data"] = e.data
    ee.attributes["index"] = e.index
    ee.attributes["internal_check"] = e.internal_check
    transition.add_element(ee)
  }
	xml_document.root.add_element(transition)	
end

def merge_elements(doc,master_id,slave_id)
	# find master
	# find slave
	# slave out transitions.each -> change source, id
	# slave in transitions.each -> change target, id 
	# delete slave
	slave=nil
	out_transitions=[]
	in_transitions=[]
	doc.root.elements.each{|e|
		slave=e if e.attributes['id']==slave_id.to_s
		out_transitions << e if e.attributes['source']==slave_id.to_s
		in_transitions	<< e if e.attributes['target']==slave_id.to_s 
	}
	out_transitions.each{|t| 
		t.attributes['source']=master_id
		t.attributes['id']=t.attributes['id'].gsub(slave_id.to_s,master_id.to_s)
	}
	in_transitions.each{|t| 
		t.attributes['target']=master_id
		t.attributes['id']=t.attributes['id'].gsub(slave_id.to_s,master_id.to_s)
	}

	doc.root.delete_element(slave)
	$log.debug "Merged #{Page.fnd({:id=>master_id}).first.name} and #{Page.fnd({:id=>slave_id}).first.name}"
end



load_model
generate_xml
