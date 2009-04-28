require 'hoe'

$:.unshift 'lib'
require 'action_mailer/ar_sendmail'

Hoe.new 'ar_mailer', ActionMailer::ARSendmail::VERSION do |ar_mailer|
  ar_mailer.rubyforge_name = 'seattlerb'
  ar_mailer.developer 'Eric Hodel', 'drbrain@segment7.net'
  ar_mailer.testlib = :minitest
  ar_mailer.extra_dev_deps << ['minitest', '~> 1.3']
end

