require "AppError.rb"
require "rexml/document"
require "FSM.rb"
require "Log.rb"
require "Helper.rb"
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
					inputs=state.attributes["inputs"]
					if(id==nil or name==nil)						
						e("XML model has inconsistent state(s)")
						raise AppError.new("XML model has inconsistent state: : name=#{name}, id=#{id}")						
					end					
					model.new_state(id,name,inputs,description,stateIsMain)
		}
		# init model transitions
		XPath.each(doc, "//transition"){|transition|					
					id=transition.attributes["id"]
					name=transition.attributes["name"]
					source=model.find_state_by_id(transition.attributes["source"])
					target=model.find_state_by_id(transition.attributes["target"])					
					action=transition.attributes["action"]
					condition=transition.attributes["condition"]
					chance=transition.attributes["chance"]
					internalState=transition.attributes["internalState"]					
					if(id==nil or name==nil or source==nil or target==nil)
						sou=(source==nil)? '' : source.name
						tar=(target==nil)? '' : target.name
						e("XML model has inconsistent transition(s)")
						raise AppError.new("XML model has inconsistent transition: name=#{name}, id=#{id}, source=#{sou}, target=#{tar}")
					end      					
					model.new_transition(id,name,source,target,condition,action,chance,internalState)
		}

		# need to decompose FSM: to split all states with inputs into 2 - state and state_INPUTDONE		
		i("Decompose")
		model.states.each{|state|
			if state.has_inputs				
				inputs=state.inputs
				state.inputs=nil
				state_done=model.new_state(state.id+STATE_IN_DONE_ID,state.name+STATE_IN_DONE_NAME,nil,'INPUT was DONE',false)
				d("#{state.name}(#{state.id}) -> #{state.name}(#{state.id}), #{state_done.name}(#{state_done.id})")
				# splitting into 2 states:
				model.transitions_from(state).each{|t|
					t.source=state_done
					d("changed source of #{t.name} to #{state_done.name}")
				}
				# connecting 2 splitted states with inputs:
				inputs.split("\n").each{|input|
					if input!=''
						model.new_transition(state.id+'-'+state_done.id,TRANSITION_IN_DONE_NAME,state,state_done,nil,input,nil,nil)					
						d "Added transition name=#{input}"
					end
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
