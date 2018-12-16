#!/usr/bin/env ruby

sets = $stdin.readlines[3..-2].join.split(/^\|-+\|$/)
nested = lambda {|h,k| h[k] = Hash.new(&nested)}
data = Hash.new(&nested)
sets.each do |set|
  set_data = set.strip.split("\n").map {|line| line.tr(',.', '').gsub(/ms|KiB/, '').split(/ *\| */)}
  set_data.each do |entry|
    name = entry[1]
    btype = entry[2]
    data[:time][btype][name] = entry[3]
    data[:memory][btype][name] = entry[4]
    data[:filesize][btype][name] = entry[5]
  end
end

data.each_with_index do |(type, entries), index|
  puts "#{type.capitalize} #{entries[entries.keys.first].keys.map {|s| "\"#{s}\""}.join(" ")}"
  entries.each do |btype, values|
    puts "\"#{btype}\" #{values.values.join(' ')}"
  end

  puts "\n\n" if index < data.size - 1
end
