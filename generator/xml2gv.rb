$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__))) unless $LOAD_PATH.include?(File.expand_path(File.dirname(__FILE__)))
CLIENT_ID=ARGV[0]
require "Proced.rb"
require "Log.rb"
include Proced
include Log
$output=""
$logfile="xml2gv.log"
$path_to_model="../model/#{CLIENT_ID}.xml"
		Log::setLog
		begin
			i "MODEL=#{$path_to_model}"
			fsm=Proced::prepareFSM
			puts fsm.export_gv([],nil)
		rescue AppError
			puts ''
		end


