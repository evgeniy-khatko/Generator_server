class Test
		attr_accessor :name, :steps, :precondition, :expected
		def initialize(name)
			@name=name
			@steps=[]
			@precondition=''
			@expected=''
		end

		class Step
			attr_accessor :from, :to, :type

			def initialize(from,to,type)
				@from=from
				@to=to
				@type=type
			end
		end
		
		def new_step(from,to,type)
			@steps << Step.new(from,to,type)
		end
end
