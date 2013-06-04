require "AppError.rb"
require "rexml/document"
require "FSM.rb"
require "Log.rb"
require "Helper.rb"
require "Alphabeth.rb"
require "TestInfo.rb"
include REXML
include Log
include Helper

# gets XML model and puts it to App memory

module Proced
	
	STATE_IN_DONE_ID='0000000000000'
	STATE_IN_DONE_NAME=' (input done)'
	TRANSITION_IN_DONE_NAME='Input'
	TAG="Init"
	
	def prepareFSM
		i("load Model")
		raise AppError.new("Model #{$path_to_model} not found") if not File.exists?($path_to_model)
		doc=Document.new getXmlFile($path_to_model)
		d "MODEL=#{$path_to_model}"
		model=FSM.new
		# init model states
		XPath.each(doc, "//state"){|state|					
					id=state.attributes["id"]
					name=state.attributes["name"]
					description=state.attributes["description"]
					stateIsMain=(state.attributes["main"]=="true")? true : false
					if(id==nil or name==nil)						
						e("XML model has inconsistent state(s)")
						raise AppError.new("XML model has inconsistent state: : name=#{name}, id=#{id}")						
					end					
          test_info = []
          state.elements.each{ |ti| 
            info = TestInfo.new(id+ti.attributes["locator"],id)
            info.locator = ti.attributes["locator"]
            info.action = ti.attributes["action"]
            info.eq_class = ti.attributes["eq_class"]
            info.data = ti.attributes["data"]
            info.internal_check = ti.attributes["internal_check"]
            test_info << info
          }
					model.new_state(id,name,description,stateIsMain,test_info)
		}
		# init model transitions
		XPath.each(doc, "//transition"){|transition|					
					id=transition.attributes["id"]
					source=model.find_state_by_id(transition.attributes["source"])
					target=model.find_state_by_id(transition.attributes["target"])					
					name=(transition.attributes["name"]==nil)? source.name+'-'+target.name : transition.attributes["name"]
					action=transition.attributes["action"]
					condition=transition.attributes["condition"]
					chance=transition.attributes["chance"]
					if(id==nil or source==nil or target==nil)
						sou=(source==nil)? '' : source.name
						tar=(target==nil)? '' : target.name
						e("XML model has inconsistent transition(s)")
						raise AppError.new("XML model has inconsistent transition: name=#{name}, id=#{id}, source=#{sou}, target=#{tar}")
					end
          test_info = []
          transition.elements.each{ |ti| 
            info = TestInfo.new(id+ti.attributes["locator"],id)
            info.locator = ti.attributes["locator"]
            info.action = ti.attributes["action"]
            info.eq_class = ti.attributes["eq_class"]
            info.data = ti.attributes["data"]
            info.internal_check = ti.attributes["internal_check"]
            test_info << info
          }
					model.new_transition(id,name,source,target,condition,action,chance,test_info)
		}

		# need to decompose FSM: to split all states with inputs into 2 - state and state_INPUTDONE		
		i("Decompose")
		model.states.each{|state|
			if !state.eq_classes.empty?# and state.decomposed == false
        state.decomposed = true        
				state_done=model.new_state(state.id+STATE_IN_DONE_ID,state.name+STATE_IN_DONE_NAME,'INPUT was DONE',false,[])
				d("#{state.name}(#{state.id}) -> #{state.name}(#{state.id}), #{state_done.name}(#{state_done.id})")
				# splitting into 2 states:
				model.transitions_from(state).each{|t|
					t.source=state_done
					d("changed source of #{t.name} to #{state_done.name}")
				}
				# connecting 2 splitted states with inputs:
        state.eq_classes.each{ |eq_class|
            test_info = state.test_info_with_eq_class( eq_class )
						tr = model.new_transition(state.id+'-'+state_done.id,eq_class,state,state_done,nil,test_info.collect(&:to_action).compact.join(";"),nil,test_info)
						d "Added transition name=#{eq_class}"
				}
			end
		}
		i("Decompose done")		
		return model
	end

	def start_server
		$server=TCPServer.open($port.to_i)
	end
end
