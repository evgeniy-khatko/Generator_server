require "Log.rb"                                     
require "Context.rb"
require "InternalError.rb"

include Log

class FSM
	
	attr_accessor :transitions, :states, :fsmContext, :current_state, :start_state, :temporary_deleted
	DEFAULT_WEIGHT=1

	class State
		attr_reader :id, :name, :description, :main, :test_info
		attr_accessor :in, :out, :has_description, :decomposed
		
		def initialize(id,name,desc,main,test_info)
			@id=id
			@name=name
			@description=desc
			@main=main
			@has_description=(desc==nil)? false : true
      @test_info = test_info
      @decomposed = false
		end
		
		def info
			desc=(@has_description) ? @description : ''
			info="[#{@id}] "+@name+": "+" main=#{@main}"+" #{desc}"
			return info
		end

    def eq_classes
      self.test_info.collect(&:eq_class).compact
    end

    def test_info_with_eq_class(eq_class)
      self.test_info.select{ |ti| ti.eq_class == eq_class }
    end

    def expected
      self.test_info.select{ |ti| ti.expected? }.compact
    end
	end

	class Transition
		attr_reader :id, :name, :chance
		attr_accessor :has_condition, :has_action, :weight, :source, :target, :condition, :action, :test_info

		def initialize(id,name,source,target,condition,action,chance,test_info)
			@id=id
			@name=name
			@source=source
			@target=target
			@condition=condition
			@has_condition=(condition==nil)? false : true
			@action=action
			@has_action=(action==nil)? false : true
			@chance=(chance==nil)? nil : chance.to_f
			@weight=(chance==nil)? DEFAULT_WEIGHT : DEFAULT_WEIGHT/@chance
      @test_info = test_info
		end
		
		def info
			info="[#{@id}] "+@name+" (#{@source.name} -> #{@target.name}) "+": "+" weight=#{@weight}"			
			internal=(@has_internal_state)? " internal=#{@internal_state}" : ''
			act=(@has_action)? " action=#{@action}" : ''
			cond=(@has_condition)? " condition=#{@condition}" : ''
			chance=(@chance==nil)? '' : " chance=#{@chance}" 
			info+=internal+act+cond+chance
			return info
		end

    def has_internal_state
      !self.test_info.collect(&:internal_check).compact.empty?
    end
    
    def internal_state
      self.test_info.collect(&:internal_check).compact.join("; ")
    end

	end	
	
	def initialize
		@fsmContext=Context.new
		@states=[]
		@transitions=[]
		@start_state=''
		@temporary_deleted=[]
	end
	
	def model_vars
		binding
	end
	
	def set_start(str)
		@start_state=str
		@previous_state=nil
		@current_state=find_state_by_name(str)		
	end

	def find_state_by_id(id)
		ind=@states.collect{|item| item.id}.index(id)
		raise InternalError.new("cant find state: #{id}") if ind==nil
		return @states[ind]	
	end
	
	def find_state_by_name(name)
		idx=@states.collect{|item| item.name}.index(name)
		raise InternalError.new("Start state = '#{name}' not found") if idx==nil
		return @states[idx]	
	end
	
	def find_transition_by_id(id)
		idx=@transitions.collect{|item| item.id}.index(id)
		raise InternalError.new("Cant find transition with id=#{id}") if idx==nil
		return @transitions[idx]	
	end
	
	def find_transition_by_states(source,target)
		@transitions.each{|t| return t if t.source==source and t.target==target}
		return nil
	end
	
	def find_transition_by_stateNames(name1,name2)
		@transitions.each{|t| return t if t.source.name==name1 and t.target.name==name2}
		return nil
	end

	def new_state(id,name,desc,main,elements=[])
		new_state=State.new(id,name,desc,main,elements)
		@states << new_state
		return new_state
	end
	
	def new_transition(id,name,source,target,condition,action,chance,elements)
		new_transition=Transition.new(id,name,source,target,condition,action,chance,elements)
		@transitions << new_transition
		return new_transition
	end
	
	def make_transition(transition)
		if $extended_mode
			# stop if transition has condition and it's been evaluated to false
			# run action otherwise
			if transition.has_condition and eval(transition.condition,@fsmContext.getBinding)==false				
				return false
			else
				eval(transition.action,@fsmContext.getBinding) if transition.has_action
				@current_state=transition.target		
			end
		else
			@current_state=transition.target		
			return true
		end
	end
	
	def info
		return "MODEL\n==States==\n#{@states.collect{|s| s.info}.join("\n")}\n==Transitions==\n#{@transitions.collect{|t| t.info}.join("\n")}\n==Current state==\n#{@current_state.info}\n==Start state==\n#{@start_state}\n"
	end
	
	def transitions_from(state)
		ary=[]
		@transitions.each{|t| ary << t if t.source==state}
		return ary
	end
	
	def transitions_to(state)
		ary=[]
		@transitions.each{|t| ary << t if t.target==state}
		return ary
	end
	
	def next_for(item)
		ary=[]
		case 
			when item.class==State then @states.each{|s| ary << s if not (transitions_to(s) & transitions_from(item)).empty?}
			when item.class==Transition then return transitions_from(item.target)
		end		
		return ary
	end	
	
	def temporary_delete_transition(t)
		raise InternalError.new("Cant temporary delete transition #{t.name} - not found in FSM") if not @transitions.include?(t)
		@temporary_deleted << @transitions.delete(t)	
	end

	def restore_deleted
		@transitions += @temporary_deleted
		
		@temporary_deleted=[]
		raise InternalError.new("Restore transitions: dublicates found after restore") if @transitions.uniq!!=nil
	end

	def clon	
		newFsm=FSM.new
		newFsm.transitions=@transitions
		newFsm.states=@states
		newFsm.fsmContext=@fsmContext.clone
		newFsm.set_start(@start_state)
		newFsm.current_state=@current_state
		return newFsm
	end

	def export_state(s,fontsize='10',fontname='Helvetica')
		shape=(s.main)? 'ellipse' : 'box'
		color_set=(s==@current_state)? ',color="lightseagreen",style=filled' : ''
		definition="#{s.id}"
		options=' [label="'+s.name+'",shape='+shape+',fontname='+fontname+',fontsize='+fontsize+color_set+'];'
		return definition+options
	end

	def export_transition(t,is_covered,is_next_transition,fontsize='10',fontname='Helvetica')
		definition="#{t.source.id} -> #{t.target.id}"
		condition=(t.has_condition)? " [#{t.condition}]" : ''
		action=(t.has_action)? " /#{t.action}/" : ''
		color="red"
		if is_covered and not is_next_transition
			color="lightseagreen"
		elsif is_next_transition
			color="orange"
		end
		options=' [label="'+t.name+condition+action+'",color="'+color+'",fontname='+fontname+',fontsize='+fontsize+'];'
		return definition+options
	end

  def export_gv(covered,next_transition,fontsize='10',fontname='Helvetica')
		out="digraph FSM {"
		@states.each{|s| out+=export_state(s,fontsize,fontname)}
		@transitions.each{|t| out+=export_transition(t,covered.include?(t),t==next_transition,fontsize,fontname)}
		out+="}"
		return out
  end	

	def stats
		out=''
		out+="STATES: #{@states.length}\n"
		out+="TRANSITIONS: #{@transitions.length}\n"
		out+="PARAMETERS: #{@fsmContext.instance_variables.length}\n"
		conditions=0
		@transitions.each{|t| conditions+=1 if t.has_condition}
		out+="CONDITIONS: #{conditions}\n"
	end
end
