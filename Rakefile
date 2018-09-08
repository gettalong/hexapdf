require 'rake/testtask'
require 'rake/clean'
require 'rubygems/package_task'

$:.unshift('lib')
require 'hexapdf'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*.rb']
  t.verbose = false
  t.warning = true
end

namespace :dev do
  PKG_FILES = FileList.new([
    'Rakefile',
    'LICENSE', 'agpl-3.0.txt',
    'README.md', 'CHANGELOG.md',
    'VERSION', 'CONTRIBUTERS',
    'bin/*',
    'lib/**/*.rb',
    'man/man1/hexapdf.1',
    'data/**/*',
    'examples/*',
    'test/**/*'
  ])

  CLOBBER << "man/man1/hexapdf.1"
  file 'man/man1/hexapdf.1' => ['man/man1/hexapdf.1.md'] do
    puts "Generating hexapdf man page"
    system "kramdown -o man man/man1/hexapdf.1.md > man/man1/hexapdf.1"
  end

  CLOBBER << "VERSION"
  file 'VERSION' do
    puts "Generating VERSION file"
    File.open('VERSION', 'w+') {|file| file.write(HexaPDF::VERSION + "\n")}
  end

  CLOBBER << 'CONTRIBUTERS'
  file 'CONTRIBUTERS' do
    puts "Generating CONTRIBUTERS file"
    `echo "  Count Name" > CONTRIBUTERS`
    `echo "======= ====" >> CONTRIBUTERS`
    `git log | grep ^Author: | sed 's/^Author: //' | sort | uniq -c | sort -nr >> CONTRIBUTERS`
  end

  spec = Gem::Specification.new do |s|
    s.name = 'hexapdf'
    s.version = HexaPDF::VERSION
    s.summary = "HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby"
    s.description = "HexaPDF is a pure Ruby library with an accompanying application for " \
      "working with PDF files.\n\nIn short, it allows creating new PDF files, manipulating " \
      "existing PDF files, merging multiple PDF files into one, extracting meta information, " \
      "text, images and files from PDF files, securing PDF files by encrypting them and " \
      "optimizing PDF files for smaller file size or other criteria.\n\nHexaPDF was designed " \
      "with ease of use and performance in mind. It uses lazy loading and lazy computing when " \
      "possible and tries to produce small PDF files by default."
    s.license = 'AGPL-3.0'

    s.files = PKG_FILES.to_a

    s.require_path = 'lib'
    s.executables = ['hexapdf']
    s.default_executable = 'hexapdf'
    s.add_dependency('cmdparse', '~> 3.0', '>= 3.0.3')
    s.add_dependency('geom2d', '~> 0.1')
    s.add_development_dependency('kramdown', '~> 1.0', '>= 1.13.0')
    s.add_development_dependency('rubocop', '~> 0.58', '>= 0.58.2')
    s.required_ruby_version = '>= 2.4'

    s.author = 'Thomas Leitner'
    s.email = 't_leitner@gmx.at'
    s.homepage = "https://hexapdf.gettalong.org"
  end

  Gem::PackageTask.new(spec) do |pkg|
    pkg.need_zip = true
    pkg.need_tar = true
  end

  desc "Upload the release to Rubygems"
  task publish_files: [:package] do
    sh "gem push pkg/hexapdf-#{HexaPDF::VERSION}.gem"
    puts 'done'
  end

  desc 'Release HexaPDF version ' + HexaPDF::VERSION
  task release: [:clobber, :package, :publish_files]

  CLOBBER << 'hexapdf.gemspec'
  task :gemspec do
    puts "Generating Gemspec"
    contents = spec.to_ruby
    File.open("hexapdf.gemspec", 'w+') {|f| f.puts(contents)}
  end

  CODING_LINE = "# -*- encoding: utf-8; frozen_string_literal: true -*-\n"

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

task clobber: 'dev:clobber'
task default: 'test'
