require 'rake'
require_relative 'lib/hexapdf/version'

PKG_FILES = FileList.new([
                           'bin/*',
                           'lib/**/*.rb',
                           'data/**/*',
                         ])
description = 'HexaPDF local development version only'

if ENV['REAL_GEM']
  PKG_FILES.include('Rakefile', 'LICENSE', 'agpl-3.0.txt', 'README.md', 'CHANGELOG.md',
                    'VERSION', 'CONTRIBUTERS', 'man/man1/hexapdf.1',
                    'examples/*', 'test/**/*')
  description = <<~DESC
    HexaPDF is a pure Ruby library with an accompanying application for working with PDF
    files.

    In short, it allows creating new PDF files, manipulating existing PDF files, merging multiple
    PDF files into one, extracting meta information, text, images and files from PDF files, securing
    PDF files by encrypting them and optimizing PDF files for smaller file size or other
    criteria.

    HexaPDF was designed with ease of use and performance in mind. It uses lazy loading and lazy
    computing when possible and tries to produce small PDF files by default.
  DESC
end

Gem::Specification.new do |s|
  s.name = 'hexapdf'
  s.version = HexaPDF::VERSION
  s.summary = "HexaPDF - A Versatile PDF Creation and Manipulation Library For Ruby"
  s.description = description
  s.license = 'AGPL-3.0'

  s.files = PKG_FILES.to_a

  s.require_path = 'lib'
  s.executables = ['hexapdf']
  s.add_dependency('cmdparse', '~> 3.0', '>= 3.0.3')
  s.add_dependency('geom2d', '~> 0.2')
  s.add_development_dependency('kramdown', '~> 1.0', '>= 1.13.0')
  s.add_development_dependency('rubocop', '~> 0.58', '>= 0.58.2')
  s.required_ruby_version = '>= 2.4'

  s.author = 'Thomas Leitner'
  s.email = 't_leitner@gmx.at'
  s.homepage = "https://hexapdf.gettalong.org"
end
