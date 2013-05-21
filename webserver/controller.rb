#! /usr/bin/ruby -w
WIN='i386-mingw32'
LIN='i686-linux'
require 'rubygems'
require 'sinatra'
#require 'rack-flash'
require 'sinatra/flash'
#require 'haml'
require 'erb'
require 'json/pure'
require 'padrino-helpers'
require 'socket'
require 'fileutils'
#require 'Sys/proctable'

if RUBY_PLATFORM==WIN
	require 'win32/process'
	require 'win32/open3'
else
	require 'open3'
	include Open3
end


                    
PORT=8000
RESIZE_FACTOR=0.5

LOG="#{File.dirname(__FILE__)}/../log"
TESTS="#{File.dirname(__FILE__)}/../tests"
XML_MODEL="#{File.dirname(__FILE__)}/../model"
ERROR_PICTURE=File.open("#{File.dirname(__FILE__)}/public/img/error.svg").read
LIB="#{File.dirname(__FILE__)}/../lib"
GENERATOR="#{File.dirname(__FILE__)}/../generator"
TMP="#{File.dirname(__FILE__)}/../tmp"

FileUtils.mkdir_p LOG unless File.exists? LOG
FileUtils.mkdir_p TESTS unless File.exists? TESTS
FileUtils.mkdir_p XML_MODEL unless File.exists? XML_MODEL
FileUtils.mkdir_p TMP unless File.exists? TMP

Sinatra.register Padrino::Helpers
configure do
	set :sessions, true
	set :environment, :development
	set :port, PORT
	set :server, %w[webrick]
	#use Rack::Flash
		
		# production mode settings
		
		#set :logging, false
		#set :dump_errors, false
		#set :raise_errors, false
		#set :show_exceptions, false
		
		# use this for development mode
		
		set :logging, true
		set :dump_errors, true
		set :raise_errors, true
		set :show_exceptions, true		
		server_pid=File.open('server.pid','w+')
		server_pid.write Process.pid
		server_pid.close
end
	
	get '/update_data' do		
		content_type :json		
		if generator_running?(session[:generator_process])
			begin
				generator_socket=TCPSocket.open('localhost',session[:generator_port])
				data=generator_socket.read
				generator_socket.close
				status=data.slice!(0).chr
				if status=='1' # => running
					svg_data=generate_svg(data,session[:filter],session[:size])				
					console_data=$gen_log.read.gsub("\n","</br>")
				elsif status=='0' # => done
					svg_data=''
					console_data='Done'
				elsif status=='2' # => generation error
					svg_data=''
					console_data=data.gsub("\n","</br>")
				else # => unknown error
					status='-1'
					svg_data=ERROR_PICTURE	
					console_data='Unknown error'
				end
			  return {:console_data => console_data, :svg_data => svg_data, :status=>status}.to_json		
		  rescue Exception => e
				svg_data=''
				status='2'
				console_data="Generator stopped</br>details: #{e.message}"
				return {:console_data =>console_data,:svg_data => svg_data, :status=>status}.to_json		
		  end
		else			
			svg_data=''
			status='2'
			console_data="Generator Stopped"
			return {:console_data =>console_data,:svg_data => svg_data, :status=>status}.to_json		
		end
	end

	get '/get_progress' do
		content_type :json
		gv=File.open(TMP+'/model.gv')
		gv_data=gv.readlines.last
		svg_data=generate_svg(gv_data,session[:filter],session[:size])				
		status=(File.exists?(TESTS+'/tests.xml'))? 0 : 1		
		#if RUBY_PLATFORM==WIN
    #  status=(Sys::ProcTable.ps(session[:generator_process].to_i)!=nil)? 1 : 0
		#end
		return {:svg_data => svg_data, :status=>status}.to_json		
	end

	get '/' do		  		
		Process.kill(9,session[:generator_process].to_i) if session[:generator_process]!=nil and generator_running?(session[:generator_process])
		session[:client_id]=Time.now.strftime("%F_%H-%M-%S") if session[:client_id]==nil
		FileUtils.rm_f(LOG)
		Dir.glob("#{TESTS}/tests.*").each{|testfile| File.delete(testfile)}
		$initial_gv_data=get_initial_data		
		erb :index   		
	end
	
	get '/prepare_data' do
		if params[:filter]==nil
			session[:filter]='dot' if session[:filter]==nil
		else
			session[:filter]=params[:filter]
		end
		case
			when params[:operation_type]==nil then
				session[:size]=(session[:size]==nil)? params[:size] : session[:size]
			when params[:operation_type]=='plus' then
				session[:size]=session[:size].split(',').collect{|dim| dim.to_f+RESIZE_FACTOR*dim.to_f}.join(',')
			when params[:operation_type]=='minus' then
				session[:size]=session[:size].split(',').collect{|dim| dim.to_f-RESIZE_FACTOR*dim.to_f}.join(',')
		end
		svg=generate_svg($initial_gv_data,session[:filter],session[:size])		
		content_type :json
	  {:svg_data => svg}.to_json
	end
	
	post '/new_file' do
		if params[:model_location]==nil or params[:model_location][:tempfile]==nil
			flash[:notice]="XML Model file is expected"
			redirect '/'
		end
		data=params[:model_location][:tempfile].read
		extension=File.extname(params[:model_location][:filename])
		if extension=='.xml'
			xml_model=File.open(XML_MODEL+"/#{session[:client_id]}.xml",'w+')
			xml_model.write data
			xml_model.close
		else
			flash[:notice]="XML Model file is expected"
		end		
		redirect '/'
	end
	
	post '/start_generator' do		
		session[:of]=params[:of]
		session[:generator_port]=find_free_port(PORT+1)
		debug=(params[:debug_mode]=='1')? ' -d' : ''
		extended=(params[:extended_mode]=='1')? ' -e' : ''
		type=' -t '+params[:generator_type]
		s=' -s '+params[:start_node]
		visualize=(params[:enable_visualization]=='1')? " -visualize -servermode #{session[:generator_port]}" : ' -visualize'
		filter=' -filter '+session[:filter]
		output=' -output '+params[:of]
		command_line="ruby #{GENERATOR}/Generator.rb -l #{session[:client_id]}.log -f #{session[:client_id]}.xml"+debug+extended+type+s+filter+output+visualize
		#puts 'START GENERATOR PROCESS: '+command_line       				
		if RUBY_PLATFORM==WIN
			session[:generator_process]=Process.create({:command_line=>command_line}).process_id
		else		
			session[:generator_process]=myspawn(command_line)			
		end
		sleep(3) # waiting for generator to open LOG file
		$gen_log=File.open(LOG+'/'+session[:client_id]+'.log')
		return nil
	end

	post '/stop_generator' do
		if session[:generator_process]!=nil and generator_running?(session[:generator_process])
			res=Process.kill(9,session[:generator_process].to_i) 
      FileUtils.rm_f(LOG)
      Dir.glob("#{TESTS}/tests.*").each{|testfile| File.delete(TESTS+'/'+testfile)}
			raise "Cant stop generation process: PID=#{session[:generator_process]}" if res==nil
			session[:generator_process]=nil
		end		
	end	
	
 	get '/send_tests' do
		of=session[:of].to_s
	  send_file(TESTS+'/tests.'+of, :disposition => 'attachment')		
	end

	
	error do
    'Sorry there was a nasty error - ' + request.env['sinatra.error'].message
  end
  
  not_found do
    'This is nowhere to be found.'
  end
	
		
	def generate_svg(gv_data,filter,size)
		i,o,e = Open3.popen3("#{filter} -Tsvg -Gsize=#{size}")		
		i.write gv_data
		i.close_write  		
		data=o.read
		errors=e.read
		o.close
		e.close
		return errors.split("\n").join("</br>") if errors!=''
		return data
	end
	
	def get_initial_data
		i,o,e = Open3.popen3("ruby #{GENERATOR}/xml2gv.rb #{session[:client_id]}")
		gv_data=o.read
		errors=e.read
		i.close
		o.close
		e.close
		return '' if errors!=''
		return gv_data
	end

	def generator_running?(p)
		begin
			result=Process.kill(0,p.to_i)
			return true
		rescue Errno::ESRCH # this is for Linux
			return false
		rescue Process::Error # this is for Wiondows and Win/process gem
			return false
		end
	end
	
	def myspawn(command_line)
		job = fork do
	  	exec command_line
		end
		Process.detach(job)
		return job
	end


	def port_free?(value)
		begin
			s=TCPServer.new('localhost',value)
			s.close
			return true
		rescue Errno::EADDRINUSE
			return false
		end
	end

	def find_free_port(initial_value)
		value=initial_value
		while not port_free?(value) do
			value+=1
		end
		puts "FOUND FREE PORT=#{value}"
		return value
	end

