require 'rake'
require 'spec/rake/spectask'

require 'rake'
require 'spec/rake/spectask'

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_files = FileList['*_spec.rb']
end

desc "Run all specs with RCov"
Spec::Rake::SpecTask.new('coverage') do |t|
  t.spec_files = FileList['*_spec.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', '*_spec.rb', '--exclude', '/Users/ken/.rvm/gems']
end