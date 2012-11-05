files = (Dir.new('stats').entries - ['.','..']).sort
files.each{|fn|
	f = File.open('stats/'+fn,'r')
	data = f.readlines
	params = data[2].split(':')[1].strip
	cond = data[3].split(':')[1].strip
	euler = data[4].split(':')[1].strip
	made = data[5].split(':')[1].strip
	mbt = data.last.split(':')[1].strip
	percA = (made == '0')? 0: ((euler.to_f/made.to_f)*100).ceil
	percMBT = (mbt == '0')? 0 : ((euler.to_f/mbt.to_f)*100).ceil
	puts File.basename(fn,'.log').gsub(/_/,',')+','+params+','+cond+','+percA.to_s+','+percMBT.to_s
} 
