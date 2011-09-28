class Test
		LINE="=============="
		attr_accessor :name, :steps, :precondition, :check
		def initialize(name)
			@name=name
			@steps=[]
			@precondition=''
			@check=''
		end
		
		def new_step(step_desc)
			@steps << step_desc
		end
		
		def txt
			prec=(@precondition=='')? '' : "Precondition\n#{LINE}\n#{@precondition}\n\n"
			return "#{LINE}#{@name.upcase}#{LINE}\n\n"+prec+"Steps\n#{LINE}\n#{@steps.join("\n")}"+"\n\nCheck\n#{LINE}\n#{@check}\n"
		end
		
		def csv
			return "#{@name.upcase},#{@precondition},#{@steps.join(";")},#{@check}"
		end
		
end
