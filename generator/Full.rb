require "Helper.rb"
require "Test.rb"
require "Log.rb"
require "AppError.rb"
include Log
include Helper

module Full		
	PRIOR_FACTOR=100	
	AVERAGE_TEST_LENGTH=4
	MAX_ITER_NUMBER=1000
	TAG="FullEdgeCoverage"
  
	def run(fsm, testsuite)
		i("run")
		# FSM in the initial state
		# use modified A* algorithm to travers graph and cover all transitions 
		# make grap recalculations with each transition if Extended mode
		
		# F construction:
		# 1. Uncovered transitions go first
		# 2. Transitions which are closer to uncovered transitions go first
		# there PRIORITY FACTOR is used to make 1st condition with higher priority		
		coverage=0
		#current_edge=first_edge
		current_transition=fsm.transitions_from(fsm.current_state).first # 1 state should always have 1 out edge, so making this edge current
		generate_gv(fsm,[],nil,$filter) if $visualization
		fsm.make_transition(current_transition) # move fsm to the 2nd state, respecting conditions and actions if extended mode		
		covered=[current_transition]		
		#remove_svg
		generate_gv(fsm,covered,current_transition,$filter) if $visualization
		current_test=Test.new(fsm.current_state.name)
		all_transitions=fsm.transitions
		iteration=0
		
		while coverage < 1 and iteration <= MAX_ITER_NUMBER # main cycle			
			sleep($delay) if $delay!=0
			f={}
			iteration+=1
			d("######################## ITERATION # #{iteration} ########################")			
			i("CURRENT STATE: #{fsm.current_state.name}")
						
			#for successors of current_edge
			#	define F for sucessors of current_edge (recalculation might be needed)
			#end
			successors=fsm.transitions_from(fsm.current_state)
			successors=successors.delete_if{|tr| tr.has_condition and eval(tr.condition,fsm.fsmContext.getBinding)==false} if $extended_mode
			found_paths={}
			successors.each{|eventual|
				d("CHECK transition=#{eventual.name}")
				transition_is_covered=(covered.include?(eventual)==true)? 1 : 0
				pth=path_to_closest_uncovered(fsm,eventual,(fsm.transitions-covered))
				found_paths[eventual]=pth                                
				f[eventual]=(covered.length+transition_is_covered)*PRIOR_FACTOR+pth.collect{|item| item.weight}.inject(0){|sum,weight| sum+weight}
				i("F (#{eventual.name}) = #{f[eventual]}")
			}
			equal_paths=found_paths.values.uniq
			if (equal_paths.length==1 and equal_paths.first==fsm.transitions) or (found_paths.values.empty?)
				e "cant find path from state=#{fsm.current_state.name} to any of uncovered=[#{(fsm.transitions-covered).collect{|i| i.name}.join("\t")}]"
				gv=File.new(Log::LOG+"/model.gv",'w')
				gv.puts fsm.export_gv(covered,nil)
				gv.close
				raise AppError.new("cant find path from state=#{fsm.current_state.name} to any of uncovered=[#{(fsm.transitions-covered).collect{|i| i.name}.join("\t")}]. Try LOGGING ('-l') -> log.txt. Check model parameters")	
			end
			#define successor with minimum F -> minF_edge
			current_transition=f.keys[f.values.index(f.values.sort.first)]
			generate_gv(fsm,covered,current_transition,$filter) if $visualization
			d("choosen=#{current_transition.name}")
			#make_transition (current_edge, minF_edge){
			#	fsm.make_transition(minF_edge)
			#	current_edge=minFedge
			#}
			if (fsm.make_transition(current_transition))
				if $extended_mode
					i("VARIABLES: #{fsm.fsmContext.instance_variables.collect{|var| "#{var}=#{fsm.fsmContext.instance_variable_get(var)} "}}")
				end
				covered.push(current_transition) if not covered.include?(current_transition)
				d("covered=[#{covered.collect{|i| i.name}.join("\t")}]")
				d("uncovered=[#{(fsm.transitions-covered).collect{|i| i.name}.join("\t")}]")
			else
				e("cant make transition #{current_transition.info} in current context")
				d("variables: #{fsm.fsmContext.instance_variables.collect{|var| "#{var}=#{@fsmContext.instance_variable_get(var)}, "}}")
				raise AppError.new("cant make transition #{current_transition.name} in current context. Try LOGGING ('-l') -> log.txt. Check model parameters")
			end
			generate_gv(fsm,covered,nil,$filter) if $visualization

			#define coverage						
			coverage=covered.length.to_f/all_transitions.length.to_f
			percent="#{(coverage*100).ceil.to_s} %"
			#i(percent)
			print "\r#{percent}"			
			if iteration==MAX_ITER_NUMBER
				e "Could not reach 100% coverage."
				raise AppError.new("Could not reach 100% coverage. Try LOGGING ('-l') -> log.txt. Check model parameters") 
			end
			# add tests
			if (fsm.current_state.main and current_test.steps.length > AVERAGE_TEST_LENGTH) or current_transition.has_internal_state
			  condition=(current_transition.has_condition)? current_transition.condition : ''
				state=(fsm.current_state.name==fsm.start_state)? '' : fsm.current_state.name
				current_test.new_step(current_transition.source.name,current_transition.target.name,current_transition.type)
				current_test.expected=(current_transition.has_internal_state)? current_transition.internal_state : testsuite.expected_by_default
				testsuite.add_test(current_test)
				current_test=Test.new(fsm.current_state.name)
				current_test.precondition=fsm.current_state.name				
			elsif
				condition=(current_transition.has_condition)? current_transition.condition : ''
				state=(fsm.current_state.name==fsm.start_state)? '' : fsm.current_state.name
				current_test.new_step(current_transition.source.name,current_transition.target.name,current_transition.type)
				current_test.expected=(current_transition.has_internal_state)? current_transition.internal_state : testsuite.expected_by_default
				if coverage==1
					testsuite.add_test(current_test)
				end
			end
		end # end of main cycle
	end # end of RUN method 

	# use BFS algorithm to find nearest uncovered edge to the current edge
	def bfs(fsm,start_transition,uncovered)
	  results={}
		#################
		##### BFS #######
		#################
		aFsm=fsm.clon
		parents={}
		context={}
		q=[]
		discovered=[]
		q.push(start_transition)
		parents[start_transition]=nil
		context[start_transition]=aFsm.fsmContext # vars values before aTransition
		found=nil
		last_discovered=nil
		while not q.empty?
			#d "QUEUE=#{q.collect{|i| i.name}.join("\t")}"
			v=q.shift
			last_discovered=v
			#d "CHECK #{v.name}"
			successors=aFsm.next_for(v)			
			if $extended_mode
				aFsm.fsmContext=context[v]
				aFsm.make_transition(v)
				#c=aFsm.fsmContext
				#d ("VARS AFTER #{v.name} => #{c.instance_variables.collect{|var| var+'='+c.instance_variable_get(var)+', '}}")
				successors=successors.delete_if{|i| i.has_condition and eval(i.condition,aFsm.fsmContext.getBinding)==false}								
			end	     			
			#d "SUCC=#{successors.collect{|i| i.name}.join("\t")}"
			successors.each{|e|
				if not parents.keys.include?(e)
					parents[e]=v
					q.push(e)
					context[e]=aFsm.fsmContext
					if uncovered.include?(e)
						found=e					
					end
				end
				break if not found==nil
			}
			break if not found==nil
		end
		results['found']=(found==nil)? false : true
		
		#################
		### Find path ###
		#################
		pth=[]
		pth << found if found!=nil
		next_in_chain=last_discovered
		while next_in_chain!=nil
			next_in_chain=parents[next_in_chain]
			pth.unshift(next_in_chain)
		end
		results['path']=pth.compact
		return results		
	end
	
	def path_to_closest_uncovered(fsm,aTransition,uncovered)
		# clonning of the fsm is used to direct travers to different directions simultaneously
		if uncovered.include?(aTransition)
			if $extended_mode
				if aTransition.has_condition
					return [aTransition] if eval(aTransition.condition,fsm.fsmContext.getBinding)==true
				else
					return [aTransition]
				end
			else
				return [aTransition]
			end
		end
		already_tried=[]		
		find_path_attempts=fsm.transitions.length
		(0..find_path_attempts).each{|iterator|
			d "bfs - iteration ##{iterator}"
			result=bfs(fsm,aTransition,uncovered)
			fsm.restore_deleted if $extended_mode
			@found=result['found']
			@pth=result['path']			
			d "PATH=#{@pth.collect{|t| t.name}.join("\t")}"
			d "FOUND=#{@found}"
			if @found
				break
			else
				break if not $extended_mode
				@pth.each{|t|
					if t.has_action and fsm.transitions_from(t.source).length > 1	 and not already_tried.include?(t)
						fsm.temporary_delete_transition(t)
						already_tried << t
						break
					end
				}
				d "Temporary deleted: #{fsm.temporary_deleted.collect{|t| t.name}.join("\t")}"
			end
		}
		if not @found
			e "WARNING! Cant find closest uncovered: current_transition=#{aTransition.name} after #{find_path_attempts} iterations, PATH=#{@pth.collect{|t| t.name}.join("\t")}, returning all transitions"
			return fsm.transitions
			#raise AppError.new("Cant find closest uncovered: current_transition=#{aTransition.name} after #{find_path_attempts} iterations, PATH=#{@pth.collect{|t| t.name}.join("\t")}")
		end
		return @pth 
	end	
end
