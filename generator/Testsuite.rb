class Testsuite
  DEFAULT_TESTSUITE_NAME=Time.new.strftime("%Y-%m-%d")
	DEFAULT_CHECK="Application internal state not changed"
  attr_accessor :name, :default_check
	LINE="**********************************"
	def initialize(name,default_check)
		@tests=[]
		@name=name
		@default_check=default_check
	end

	def add_test(test)
		@tests << test
	end
	
	def exportTxt
		return "#{LINE}\n#{name.upcase}\n#{LINE}\n\n#{@tests.collect{|t| t.txt}.join("\n")}"
	end
	
	def exportCsv
		return "#{name}\nNAME,PRECONDITION,STEPS,CHECK\n#{@tests.collect{|t| t.csv}.join("\n")}"
	end		
end