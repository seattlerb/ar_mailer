= ar_mailer

* http://seattlerb.rubyforge.org/ar_mailer
* http://rubyforge.org/projects/seattlerb
* http://rubyforge.org/tracker/?func=add&group_id=1513&atid=5921

== DESCRIPTION:

ar_mailer is a two-phase delivery agent for ActionMailer.  Even delivering
email to the local machine may take too long when you have to send hundreds of
messages.  ar_mailer allows you to store messages into the database for later
delivery by a separate process, ar_sendmail.

== SYNOPSIS:

See ActionMailer::ARMailer for instructions on using ar_mailer.

See ar_sendmail -h for options to ar_sendmail.

An rc.d script is included in share/ar_sendmail for *BSD operating systems.

== INSTALL:

* gem install ar_mailer

NOTE: You may need to delete an smtp_tls.rb file if you have one lying
around.  ar_mailer supplies it own.

