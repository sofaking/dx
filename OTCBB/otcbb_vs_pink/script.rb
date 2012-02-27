matched = 0
compared = 0
wrong_exch = 0
otcfile_arr = []
unmatched_symbols_count = {}
to_write_unmatched = false
otcfile_keys = {}
Pinkfile = "trades_pink"
OTCfile = "trades_otcbb"

def print_row(*args)
  args.each do |arg|
    case arg
      when String, Symbol
	print "%9s" % arg
      when Integer
	print "%9d" % arg
    end
  end
  print "\n"
end

distribution_ranges = {
  :upto1s  => "0...2",
  :upto2s  => "2...3",
  :upto5s  => "3..5",
  :upto10s => "6..10",
  :upto60s => "11..60",
  :upto10m => "61..600",
  :upto30m => "601..1800",
  :upto1h  => "1801..3600",
  :upto2h  => "3601..7200",
  :upto1d  => "7201..86400" }.each_key { |k| eval "@#{k} = 0" }

# Title
print_row "compared",
	  *distribution_ranges.keys,
	  "matched",
	  "wrngexch"

pinkfile = IO.readlines(Pinkfile)
otcfile = IO.readlines(OTCfile)

otcfile.each_index do |index|
  splitted_line = otcfile[index].split
  symbol = splitted_line[1].to_sym if splitted_line[1]
  otcfile[index] =~ /^Trade/ ? otcfile_arr << splitted_line : otcfile_arr << nil
  otcfile_keys[symbol] ||= [] # Create new key if it didn't exist
  otcfile_keys[symbol] << index # Save line number to index
end

iterations = 9
iterations.times do |iteration|
  pinkfile.each_index do |pinkindex|
    #break if pinkindex == 10
    #puts compared if pinkindex > 14440

    line = pinkfile[pinkindex]
    next unless line =~ /^Trade&V/
    next if pinkfile[pinkindex].nil?

    symbol, time, price, size = line.split[1..4]
    time = time.to_i
    symbol = symbol.to_sym
    compared += 1 if iteration == 0

    next unless otcfile_keys.has_key? symbol

    unmatched = true

    otcfile_keys[symbol].each_index do |index|
      line_num = otcfile_keys[symbol][index]
      next if line_num.nil?
      otcline = otcfile_arr[line_num]
      timediff = otcline[2].to_i - time
      from, to = case iteration
	when 0 then [0, 1]
	when 1 then [2, 2]
	when 2 then [3, 5]
	when 3 then [6, 10]
	when 4 then [11, 60]
	when 5 then [61, 600]
	when 6 then [601, 1800]
	when 7 then [1801, 3600]
	when 8 then [3601, 7200]
	else        [nil, nil]
      end
      if from
	next unless timediff.abs.between? from, to
      end

      if otcline[3] == price and otcline[4] == size
	distribution_ranges.each do |k,v|
	  eval("@#{k} += 1") if eval("(#{v}) === timediff.abs")
	end

	matched += 1
	unmatched = false
	wrong_exch += 1 if otcline[0] != "Trade&V"
	otcfile_arr[line_num]        = nil # Delete matched line
	otcfile_keys[symbol][index]  = nil # Delete line from index
	pinkfile[pinkindex]          = nil # Delete matched line

	break
      end
    end

    if unmatched and iteration == iterations - 1 #and size.to_i >= 100 
      unmatched_symbols_count[symbol] ||= 0
      unmatched_symbols_count[symbol] += 1 # Add 1 to count of unmatched
    end

    if compared % 10000 == 0 or ( iteration != 0 and line == pinkfile.last )
      print_row compared,
		*distribution_ranges.keys.map { |k| eval "@#{k}" },
		matched,
		wrong_exch
    end
  end
end

if to_write_unmatched
  File.open "unmatched_symbols.csv", "w" do |file|
    unmatched_symbols_count.sort_by { |k,v| v }.reverse.each { |k,v| file.puts "#{k},#{v}" }
    puts "Unmatched symbols file was written"
  end
#print "\n"

  file1 = Pinkfile + "_unmatched"
  file2 = OTCfile  + "_unmatched"
  File.delete file1 if File.exists?(file1)
  File.delete file2 if File.exists?(file2)

  File.open file1, "w" do |file|
    pinkfile.each { |line| file.puts line unless line.nil? }
    puts "#{file1} file was written"
  end

  File.open file2, "w" do |file|
    otcfile_arr.each { |line| file.puts line.join "\t" unless line.nil? }
    puts "#{file2} file was written"
  end
end
