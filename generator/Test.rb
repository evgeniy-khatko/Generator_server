class Test
		attr_accessor :name, :steps
		def initialize(name)
			@name=name
			@steps=[]
		end

		class Step
			attr_accessor :from, :to, :element, :params, :condition, :expected_elements, :internal_check

			def initialize(from,to,element,params='',condition='',expected_elements='',internal_check='')
				@from=from
				@to=to
        @element = element
        @condition = condition
        @expected_elements = expected_elements
        @internal_check = internal_check
        @params = params
			end
		end
		
		def new_step(from,to,element,params,condition,expected_elements,internal_check)
			@steps << Step.new(from,to,element,params,condition,expected_elements,internal_check)
		end
end
