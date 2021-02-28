#!/usr/bin/env ruby

$:.unshift(File.join(__dir__, '../../lib'))
require 'hexapdf'
require 'hexapdf/cli'
require 'timeout'

args = Shellwords.split("mod --force {} /tmp/bench-result.pdf")
result_file = File.open(ARGV[1], 'a')
count = 0
Dir.glob(File.join(ARGV[0], '*')).each do |file|
  begin
    #HexaPDF::CLI::Application.new.parse(args.map {|a| a.gsub(/{}/, file) })
    HexaPDF::Document.open(file) do |doc|
      doc.validate(auto_correct: true, only_loaded: false)
    end
    count += 1
  rescue StandardError
    result_file.puts(file)
  end
end
puts count
result_file.close
