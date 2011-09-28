require "rubygems"
require "logger"
require "InternalError.rb"

module Log
  LOG="../log"
	DEFAULT_LOG_TAG="Generator"
	def setLog
		if $output=='stdout'
			$log=Logger.new(STDOUT)
		else
			file=File.new(LOG+'/'+$logfile,'w+')
			file.sync=true
			$log=Logger.new(file)
		end
		$log.formatter = proc { |severity, datetime, progname, msg|
    	"#{severity}: #{msg}\n"
  	}
  	if $debug_mode
  		$log.level=Logger::DEBUG
  	else
  		$log.level=Logger::INFO
  	end
	end
	
	def setTag(tag=DEFAULT_LOG_TAG)
		$log.formatter = proc { |severity, datetime, progname, msg|
    	"#{msg}\n"
			#"#{tag}[#{severity}]: #{msg}\n"
  	}
	end
	
	def d(mes)
		$log.debug(mes)	
	end
	
	def e(mes)
		$log.error(mes)
	end
	
	def i(mes)
		$log.info(mes)
	end
	
	def closeLog
		$log.close
	end
end
