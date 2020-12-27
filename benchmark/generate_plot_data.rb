#!/usr/bin/env ruby

nested = lambda {|h,k| h[k] = Hash.new(&nested)}
data = Hash.new(&nested)
$stdin.each_line do |line|
  next unless line =~ /^\| \w+/
  entry = line.gsub(/ms|KiB/, '').split(/ *\| */)
  name = entry[1]
  btype = entry[2]
  data[:time][btype][name] = entry[3].tr(',.', '')
  data[:memory][btype][name] = entry[4].tr(',.', '')
  data[:filesize][btype][name] = entry[5].tr(',.', '')
end

data.each_with_index do |(type, entries), index|
  puts "#{type.capitalize} #{entries[entries.keys.first].keys.map {|s| "\"#{s}\""}.join(" ")}"
  entries.each do |btype, values|
    puts "\"#{btype}\" #{values.values.join(' ')}"
  end

  puts "\n\n" if index < data.size - 1
end
