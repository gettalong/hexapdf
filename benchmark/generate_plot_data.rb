#!/usr/bin/env ruby

benchmark = ARGV[0]

nested = lambda {|h,k| h[k] = Hash.new(&nested)}
data = Hash.new(&nested)
$stdin.each_line do |line|
  next unless line =~ /^\| \w+/
  entry = line.gsub(/ms|KiB/, '').split(/ *\| */)
  name = entry[1]
  btype = entry[2]
  if benchmark == 'pdf_corpus'
    value, total = entry[3].split('/').map(&:to_i)
    data[:percentage][btype][name] = value.to_f / total * 100
  else
    data[:time][btype][name] = entry[3].tr(',.', '')
    data[:memory][btype][name] = entry[4].tr(',.', '')
    data[:filesize][btype][name] = entry[5].tr(',.', '')
  end
end

data.each_with_index do |(type, entries), index|
  puts "#{type.capitalize} #{entries[entries.keys.first].keys.map {|s| "\"#{s}\""}.join(" ")}"
  entries.each do |btype, values|
    puts "\"#{btype}\" #{values.values.join(' ')}"
  end

  puts "\n\n" if index < data.size - 1
end
