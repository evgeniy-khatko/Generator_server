class Test
		attr_accessor :name, :steps
		def initialize(name)
			@name=name
			@steps=[]
		end

		class Step
			attr_accessor :from, :to, :user_action, :user_action_params, :condition, :expected_elements, :internal_check

			def initialize(from,to,user_action='',user_action_params='',condition='',expected_elements='',internal_check='')
				@from=from
				@to=to
        @user_action = user_action
        @user_action_params = user_action_params
        @condition = condition
        @expected_elements = expected_elements
        @internal_check = internal_check
			end
		end
		
		def new_step(from,to,user_action,user_action_params,condition,expected_elements,internal_check)
			@steps << Step.new(from,to,user_action,user_action_params,condition,expected_elements,internal_check)
		end
end
