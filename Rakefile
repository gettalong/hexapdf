require 'rake/testtask'
require 'rake/clean'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*.rb']
  t.verbose = false
  t.warning = true
end

namespace :dev do

  CLOBBER << "man/man1/hexapdf.1"
  file 'man/man1/hexapdf.1' => ['man/man1/hexapdf.1.md'] do
    puts "Generating hexapdf man page"
    system "ronn --pipe -r man/man1/hexapdf.1.md > man/man1/hexapdf.1"
  end

  CODING_LINE = "# -*- encoding: utf-8 -*-\n"

  desc "Insert/Update copyright notice"
  task :update_copyright do
    license = File.readlines(File.join(__dir__, 'LICENSE')).map do |l|
      l.strip.empty? ? "#\n" : "# #{l}"
    end.join
    statement = CODING_LINE + "#\n#--\n# This file is part of HexaPDF.\n#\n" + license + "#++\n"
    inserted = false
    Dir["lib/**/*.rb"].each do |file|
      unless File.read(file).start_with?(statement)
        inserted = true
        puts "Updating file #{file}"
        old = File.read(file)
        unless old.gsub!(/\A#{Regexp.escape(CODING_LINE)}#\n#--.*?\n#\+\+\n/m, statement)
          old.gsub!(/\A(#{Regexp.escape(CODING_LINE)})?/, statement)
        end
        File.write(file, old)
      end
    end
    puts "Look through the above mentioned files and correct all problems" if inserted
  end
end

task default: 'test'
