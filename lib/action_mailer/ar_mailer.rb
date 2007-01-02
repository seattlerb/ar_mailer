require 'action_mailer'

##
# Adds sending email through an ActiveRecord table as a delivery method for
# ActionMailer.
#
# == Converting to ActionMailer::ARMailer
#
# Go to your Rails project:
# 
#   $ cd your_rails_project
# 
# Create a new migration:
# 
#   $ ar_sendmail --create-migration
# 
# You'll need to redirect this into a file.  If you want a different name
# provide the --table-name option.
# 
# Create a new model:
# 
#   $ ar_sendmail --create-model
# 
# You'll need to redirect this into a file.  If you want a different name
# provide the --table-name option.
# 
# Change your email classes to inherit from ActionMailer::ARMailer instead of
# ActionMailer::Base:
# 
#   --- app/model/emailer.rb.orig   2006-08-10 13:16:33.000000000 -0700
#   +++ app/model/emailer.rb        2006-08-10 13:16:43.000000000 -0700
#   @@ -1,4 +1,4 @@
#   -class Emailer < ActionMailer::Base
#   +class Emailer < ActionMailer::ARMailer
#    
#   def comment_notification(comment)
#     from comment.author.email
# 
# Edit config/environments/production.rb and set the delivery agent:
# 
#   $ grep delivery_method config/environments/production.rb
#   ActionMailer::Base.delivery_method = :activerecord
# 
# Run ar_sendmail:
# 
#   $ ar_sendmail
# 
# You can also run it from cron with -o, or as a daemon with -d.
#
# See <tt>ar_sendmail -h</tt> for full details.

class ActionMailer::ARMailer < ActionMailer::Base

  ##
  # Adds +mail+ to the Email table.  Only the first From address for +mail+ is
  # used.

  def perform_delivery_activerecord(mail)
    mail.destinations.each do |destination|
      Email.create :mail => mail.encoded,
                   :to => destination,
                   :from => mail.from.first
    end
  end

end

