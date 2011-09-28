class InternalError < StandardError
	
	@@tag='Internal tool error: '

	def initialize(desc)
		super(@@tag+desc)
	end
	
	def self.tag
		@@tag
	end
	
	def self.tag=(value)
		@@tag=value
	end

end