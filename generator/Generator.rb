$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__))) unless $LOAD_PATH.include?(File.expand_path(File.dirname(__FILE__)))

require "Proced.rb"
require "Helper.rb"
require "Full.rb"
require "Log.rb"
include Proced
include Helper
include Full
include Log
	begin
		Helper::setGlobalParams
		Log::setLog		
		i 'Set global parameters'
		d "Globar params: debug=#{$debug_mode}\tfile=#{$path_to_model}\tstart=#{$start_node}\textended=#{$extended_mode}\tlogto=#{$output}\ttype=#{$type}\tkeyword=#{$keyword}\texport=#{$export}\tdelay=#{$delay}\tvisualization=#{$visualize}\tfilter=#{$filter}\tservermode=#{$servermode}\tport=#{$port}"		
		Proced::start_server if $servermode
		
		Log::setTag(Proced::TAG)
		fsm=Proced::prepareFSM
		
		Log::setTag(Helper::TAG)
		testsuite=Helper::setTestsuite

		Log::setTag(Full::TAG)
		fsm.set_start($start_node)
		Full::run(fsm, testsuite)

		Log::setTag(Helper::TAG)
		Helper::write_tests(testsuite)
		if $servermode
			transition_area=$server.accept
			transition_area.print '0'
			transition_area.close
		end
		Log::closeLog

	rescue Exception => e		
		if $servermode
			transition_area=$server.accept
			transition_area.print '2'
			transition_area.puts(e.message)
			transition_area.close
		else
			i e.message
			i e.backtrace
			d e.message
			d e.backtrace
		end
		Log::closeLog if $logfile!=nil
		Helper::GV_FILE.close
	end

