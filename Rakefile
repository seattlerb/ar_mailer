require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'

$VERBOSE = nil

spec = Gem::Specification.new do |s|
  s.name = 'ar_mailer'
  s.version = '1.1.1'
  s.summary = 'A two-phase deliver agent for ActionMailer'
  s.description = 'Queues emails from ActionMailer in the database and uses a separate process to send them.  Reduces sending overhead when sending hundreds of emails.'
  s.author = 'Eric Hodel'
  s.email = 'eric@robotcoop.com'

  s.has_rdoc = true
  s.files = File.read('Manifest.txt').split($/)
  s.require_path = 'lib'

  s.executables = ['ar_sendmail']
end

desc 'Run tests'
task :default => [ :test ]

Rake::TestTask.new('test') do |t|
  t.libs << 'test'
  t.pattern = 'test/test_*.rb'
  t.verbose = true
end

desc 'Update Manifest.txt'
task :update_manifest do
  sh "find . -type f | sed -e 's%./%%' | egrep -v 'svn|swp|~' | egrep -v '^(doc|pkg)/' | sort > Manifest.txt"
end

desc 'Generate RDoc'
Rake::RDocTask.new :rdoc do |rd|
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.add 'lib', 'README', 'LICENSE', 'CHANGES'
  rd.main = 'README'
  rd.options << '-d' if `which dot` =~ /\/dot/
  rd.options << '-t ar_mailer'
end

desc 'Generate RDoc for dev.robotcoop.com'
Rake::RDocTask.new :dev_rdoc do |rd|
  rd.rdoc_dir = '../../../www/trunk/dev/html/Tools/ar_mailer'
  rd.rdoc_files.add 'lib', 'README', 'LICENSE', 'CHANGES'
  rd.main = 'README'
  rd.options << '-d' if `which dot` =~ /\/dot/
  rd.options << '-t ar_mailer'
end

desc 'Build Gem'
Rake::GemPackageTask.new spec do |pkg|
  pkg.need_tar = true
end

desc 'Clean up'
task :clean => [ :clobber_rdoc, :clobber_package ]

desc 'Clean up'
task :clobber => [ :clean ]

# vim: syntax=Ruby
