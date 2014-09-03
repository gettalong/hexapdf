require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/*.rb']
  t.verbose = true
  t.warning = true
end

task :default => 'test'
