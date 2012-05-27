require 'rexml/document'
class Testsuite
  DEFAULT_TESTSUITE_NAME=Time.new.strftime("%Y-%m-%d")
	EXPECTED_BY_DEFAULT="Application internal state not changed"
  attr_accessor :name, :expected_by_default

	def initialize(name,expected_by_default=EXPECTED_BY_DEFAULT)
		@tests=[]
		@name=name
		@expected_by_default=expected_by_default
	end

	def add_test(test)
		@tests << test
	end
	def export
		output=''
		out=Document.new
		out.add_element("out")
		n=Element.new("name")
		n.text=@name
		out.root.add_element(n)
		@tests.each{|test|
			t=Element.new("test")
			t.attributes["name"]=test.name
			t.attributes["precondition"]=test.precondition
			t.attributes["expected"]=test.expected
			test.steps.each{|step|
				s=Element.new("step")
				s.attributes["from"]=step.from
				s.attributes["to"]=step.to
				s.attributes["type"]=step.type
				t.add_element(s)
			}
			out.root.add_element(t)
		}
		out.write(output,4)
		return output
	end	
	def stats
		out=''
		tests=@tests.length
		steps=0
		@tests.each{|test| steps+=test.steps.length}
		average_test_length=(tests==0)? 0 : steps/tests
		out+="TESTS: #{tests}\n"
		out+="AVERAGE TEST LENGTH: #{average_test_length}\n"
	end
end
