class Test
		attr_accessor :name, :steps
		def initialize(name)
			@name=name
			@steps=[]
		end

		class Step
			attr_accessor :from, :to, :test_info

			def initialize(from,to,test_info)
				@from=from
				@to=to
        @test_info = test_info
			end
		end
		
		def new_step(from,to,test_info)
			@steps << Step.new(from,to,test_info)
		end
end
