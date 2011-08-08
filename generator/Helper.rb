require "Test.rb"
require "Log.rb"
require "Testsuite.rb"
require "socket"

module Helper
	TMP="../tmp"
	IMG="../webserver/public/img"
	MODEL="../model"
	TESTS="../tests"
	TAG="Helper"
	GV_FILE=File.new("#{TMP}/model.gv","w")
	GV_FILE.sync=true
	def items_info(items)
		return items.collect{|i| i.info}.join("\t")
	end

	def generate_gv(fsm,covered,next_transition,filter)
		if $servermode
			transition_area=$server.accept
			transition_area.print '1'
			transition_area.puts(fsm.export_gv(covered,next_transition))
			transition_area.close
		else
			GV_FILE.puts(fsm.export_gv(covered,next_transition))
		end
	end

	def setGlobalParams
		par=ARGV
		if par.include?("-h")
			puts ("Parameters:\n-t algorithm_type (full, smoke, directed 'keyword'... default=full)\n[-f path_fo_graph] (default=#{MODEL}/model.xml)\n[-s start_node_label] (default='Start')\n[-csv] export Test suite in CSV format (default is TXT format)\n[-e] switch to EXTENDED mode (default EXTENDED=false)\n[-d] switch to DEBUG mode (default DEBUG=false)\n[-l] switch to write log to log.txt (default=$STDOUT)\n\n")
			raise ArgumentError.new("USAGE") 
		end
		
		d=par.index('-d')
		$debug_mode=(d==nil)? false : true
		
		f=par.index('-f')
		$path_to_model=(f==nil or par[f+1]==nil)? "#{MODEL}/model.xml" : MODEL+'/'+par[f+1]
		
		s=par.index('-s')
		$start_node=(s==nil)? "Start" : par[s+1]

		e=par.index('-e')
		$extended_mode=(e==nil)? false : true
		
		l=par.index('-l')
		if l==nil			
			$output='stdout'
		elsif	par[l+1].to_s[0,1]=='-' or par[l+1]==nil
			$logfile='generator.log'
		else
			$logfile=par[l+1]
		end
		
		t=par.index('-t')
		$type=(t==nil or par[t+1]==nil)? 'Full' : par[t+1]
		$keyword=par[t+2] if $type=='Directed'
		
		output=par.index('-output')
		$export=(output==nil or (par[output+1]!='txt' and par[output+1]!='csv'))? 'txt' : par[output+1]

		delay=par.index("-delay")
		$delay=(delay==nil or par[delay+1]==nil)? 0 : par[delay+1].to_f/1000

		filter=par.index("-filter")
		$filter=(filter==nil or par[filter+1]==nil)? 'dot' : par[filter+1]

		vis=par.index("-visualize")
		$visualization=(vis==nil)? false : true

		servermode=par.index("-servermode")
		$servermode=(servermode==nil)? false : true
		$port=par[servermode+1] if $servermode
	end
	
	def setTestsuite(name=Testsuite::DEFAULT_TESTSUITE_NAME,default_check=Testsuite::DEFAULT_CHECK)
		type=($type=='Directed')? $type.upcase+"(#{$keyword})" : $type.upcase
		testsuite=Testsuite.new(Testsuite::DEFAULT_TESTSUITE_NAME+"_#{type}",Testsuite::DEFAULT_CHECK)
		return testsuite
	end
	
	def write_tests(testsuite)
		i("write tests")
		f=File.open(TESTS+'/'+'tests'+".#{$export}","wb+")
		case $export
			when 'txt' then f.puts testsuite.exportTxt.gsub("\n","\r\n")
			when 'csv' then f.puts testsuite.exportCsv
		end
		f.rewind
		f.close
		return f
	end
	

	def getXmlFile(xmlFile)
		if not File.exists?(xmlFile)
			e("XML model not found: "+xmlFile)
			raise AppError.new("XML model not found: "+xmlFile)
		else
			return File.open(xmlFile)
		end
	end	

end   
