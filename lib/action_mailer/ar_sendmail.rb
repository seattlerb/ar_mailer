require 'optparse'
require 'rubygems'
require 'action_mailer'

class Object # :nodoc:
  unless respond_to? :path2class then
    def self.path2class(path)
      path.split(/::/).inject self do |k,n| k.const_get n end
    end
  end
end

##
# Hack in RSET

class Net::SMTP # :nodoc:

  unless instance_methods.include? 'reset' then
    ##
    # Resets the SMTP connection.

    def reset
      getok 'RSET'
    end
  end

end

##
# ActionMailer::ARSendmail delivers email from the email table to the
# configured SMTP server.
#
# See ar_sendmail -h for the full list of supported options.
#
# The interesting options are:
# * --daemon
# * --mailq
# * --create-migration
# * --create-model
# * --table-name

class ActionMailer::ARSendmail

  ##
  # Email delivery attempts per run

  attr_accessor :batch_size

  ##
  # Seconds to delay between runs

  attr_accessor :delay

  ##
  # Be verbose

  attr_accessor :verbose

  ##
  # ActiveRecord class that holds emails

  attr_reader :email_class

  ##
  # True if only one delivery attempt will be made per call to run

  attr_reader :once

  ##
  # Creates a new migration using +table_name+ and prints it on stdout.

  def self.create_migration(table_name)
    puts <<-EOF
class Add#{table_name.classify} < ActiveRecord::Migration
  def self.up
    create_table :#{table_name.tableize} do |t|
      t.column :from, :string
      t.column :to, :string
      t.column :last_send_attempt, :integer, :default => 0
      t.column :mail, :text
    end
  end

  def self.down
    drop_table :email
  end
end
    EOF
  end

  ##
  # Creates a new model using +table_name+ and prints it on stdout.

  def self.create_model(table_name)
    puts <<-EOF
class #{table_name.classify} < ActiveRecord::Base
end
    EOF
  end

  ##
  # Prints a list of unsent emails and the last delivery attempt, if any.
  #
  # If ActiveRecord::Timestamp is not being used the arrival time will not be
  # known.  See http://api.rubyonrails.org/classes/ActiveRecord/Timestamp.html
  # to learn how to enable ActiveRecord::Timestamp.

  def self.mailq
    emails = Email.find :all

    if emails.empty? then
      puts "Mail queue is empty"
      return
    end

    total_size = 0

    puts "-Queue ID- --Size-- ----Arrival Time---- -Sender/Recipient-------"
    emails.each do |email|
      size = email.mail.length
      total_size += size

      create_timestamp = email.created_at rescue
                         email.created_on rescue
                         Time.at(email.created_date) rescue # for Robot Co-op
                         nil

      created = if create_timestamp.nil? then
                  '             Unknown'
                else
                  create_timestamp.strftime '%a %b %d %H:%M:%S'
                end

      puts "%10d %8d %s  %s" % [email.id, size, created, email.from]
      if email.last_send_attempt > 0 then
        puts "Last send attempt: #{Time.at email.last_send_attempt}"
      end
      puts "                                         #{email.to}"
      puts
    end

    puts "-- #{total_size/1024} Kbytes in #{emails.length} Requests."
  end

  ##
  # Processes command line options in +args+

  def self.process_args(args)
    name = File.basename $0

    options = {}
    options[:Daemon] = false
    options[:Delay] = 60
    options[:Once] = false
    options[:TableName] = 'Email'
    options[:Chdir] = '.'
    options[:RailsEnv] = ENV['RAILS_ENV']

    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{name} [options]"
      opts.separator ''

      opts.separator "#{name} scans the email table for new messages and sends them to the"
      opts.separator "website's configured SMTP host."
      opts.separator ''
      opts.separator "#{name} must be run from a Rails application's root."

      opts.separator ''
      opts.separator 'Sendmail options:'

      opts.on("-b", "--batch-size BATCH_SIZE",
              "Maximum number of emails to send per delay",
              "Default: Deliver all available emails", Integer) do |batch_size|
        options[:BatchSize] = batch_size
      end

      opts.on(      "--delay DELAY",
              "Delay between checks for new mail",
              "in the database",
              "Default: #{options[:Delay]}", Integer) do |delay|
        options[:Delay] = delay
      end

      opts.on("-o", "--once",
              "Only check for new mail and deliver once",
              "Default: #{options[:Once]}") do |once|
        options[:Once] = once
      end

      opts.on("-d", "--daemonize",
              "Run as a daemon process",
              "Default: #{options[:Daemon]}") do |daemon|
        options[:Daemon] = true
      end

      opts.on(      "--mailq",
              "Display a list of emails waiting to be sent") do |mailq|
        options[:MailQ] = true
      end

      opts.separator ''
      opts.separator 'Setup Options:'

      opts.on(      "--create-migration",
              "Prints a migration to add an Email table",
              "to stdout") do |create|
        options[:Migrate] = true
      end

      opts.on(      "--create-model",
              "Prints a model for an Email ActiveRecord",
              "object to stdout") do |create|
        options[:Model] = true
      end

      opts.separator ''
      opts.separator 'Generic Options:'

      opts.on("-c", "--chdir PATH",
              "Use PATH for the application path",
              "Default: #{options[:Chdir]}") do |path|
        usage opts, "#{path} is not a directory" unless File.directory? path
        usage opts, "#{path} is not readable" unless File.readable? path
        options[:Chdir] = path
      end

      opts.on("-e", "--environment RAILS_ENV",
              "Set the RAILS_ENV constant",
              "Default: #{options[:RailsEnv]}") do |env|
        options[:RailsEnv] = env
      end

      opts.on("-t", "--table-name TABLE_NAME",
              "Name of table holding emails",
              "Used for both sendmail and",
              "migration creation",
              "Default: #{options[:TableName]}") do |name|
        options[:TableName] = name
      end

      opts.on("-v", "--[no-]verbose",
              "Be verbose",
              "Default: #{options[:Verbose]}") do |verbose|
        options[:Verbose] = verbose
      end

      opts.on("-h", "--help",
              "You're looking at it") do
        usage opts
      end

      opts.separator ''
    end

    opts.parse! args

    return options if options.include? :Migrate or options.include? :Model

    ENV['RAILS_ENV'] = options[:RailsEnv]

    Dir.chdir options[:Chdir] do
      begin
        require 'config/environment'
      rescue LoadError
        usage opts, <<-EOF
#{name} must be run from a Rails application's root to deliver email.
#{Dir.pwd} does not appear to be a Rails application root.
          EOF
      end
    end

    return options
  end

  ##
  # Processes +args+ and runs as appropriate

  def self.run(args = ARGV)
    options = process_args args

    if options.include? :Migrate then
      create_migration options[:TableName]
      exit
    elsif options.include? :Model then
      create_model options[:TableName]
      exit
    elsif options.include? :MailQ then
      mailq
      exit
    end

    if options[:Daemon] then
      require 'webrick/server'
      WEBrick::Daemon.start
    end

    new(options).run

  rescue SystemExit
    raise
  rescue SignalException
    exit
  rescue Exception => e
    $stderr.puts "Unhandled exception #{e.message}(#{e.class}):"
    $stderr.puts "\t#{e.backtrace.join "\n\t"}"
    exit 1
  end

  ##
  # Prints a usage message to $stderr using +opts+ and exits

  def self.usage(opts, message = nil)
    if message then
      $stderr.puts message
      $stderr.puts
    end

    $stderr.puts opts
    exit 1
  end

  ##
  # Creates a new ARSendmail.
  #
  # Valid options are:
  # <tt>:BatchSize</tt>:: Maximum number of emails to send per delay
  # <tt>:Delay</tt>:: Delay between deliver attempts
  # <tt>:TableName</tt>:: Table name that stores the emails
  # <tt>:Once</tt>:: Only attempt to deliver emails once when run is called
  # <tt>:Verbose</tt>:: Be verbose.

  def initialize(options = {})
    options[:Delay] ||= 60
    options[:TableName] ||= 'Email'

    @batch_size = options[:BatchSize]
    @delay = options[:Delay]
    @email_class = Object.path2class options[:TableName]
    @once = options[:Once]
    @verbose = options[:Verbose]
  end

  ##
  # Delivers +emails+ to ActionMailer's SMTP server and destroys them.

  def deliver(emails)
    Net::SMTP.start server_settings[:address], server_settings[:port],
                    server_settings[:domain], server_settings[:user],
                    server_settings[:password],
                    server_settings[:authentication] do |smtp|
      until emails.empty? do
        email = emails.shift
        begin
          res = smtp.send_message email.mail, email.from, email.to
          email.destroy
          log "sent email %011d from %s to %s: %p" %
                [email.id, email.from, email.to, res]
        rescue Net::SMTPFatalError => e
          log "5xx error sending email %d, removing from queue: %p(%s):\n\t%s" %
                [email.id, e.message, e.class, e.backtrace.join("\n\t")]
          email.destroy
          smtp.reset
        rescue Net::SMTPServerBusy => e
          log "server too busy, sleeping #{@delay} seconds"
          sleep delay unless $TESTING
          return
        rescue Net::SMTPServerBusy, Net::SMTPUnknownError, Net::SMTPSyntaxError, TimeoutError => e
          email.last_send_attempt = Time.now.to_i
          email.save rescue nil
          log "error sending email %d: %p(%s):\n\t%s" %
                [email.id, e.message, e.class, e.backtrace.join("\n\t")]
          smtp.reset
        end
      end
    end
  rescue Net::SMTPServerBusy, SystemCallError
    # ignore SMTPServerBusy/EPIPE/ECONNRESET from Net::SMTP.start's ensure
  end

  ##
  # Prepares ar_sendmail for exiting

  def do_exit
    log "caught signal, shutting down"
    exit
  end

  ##
  # Returns emails in email_class that haven't had a delivery attempt in the
  # last 300 seconds.

  def find_emails
    options = { :conditions => ['last_send_attempt < ?', Time.now.to_i - 300] }
    options[:limit] = batch_size unless batch_size.nil?
    mail = @email_class.find :all, options

    log "found #{mail.length} emails to send"
    mail
  end

  ##
  # Installs signal handlers to gracefully exit.

  def install_signal_handlers
    trap 'TERM' do do_exit end
    trap 'INT'  do do_exit end
  end

  ##
  # Logs +message+ if verbose

  def log(message)
    $stderr.puts message if @verbose
    ActionMailer::Base.logger.info "ar_sendmail: #{message}"
  end

  ##
  # Scans for emails and delivers them every delay seconds.  Only returns if
  # once is true.

  def run
    install_signal_handlers

    loop do
      now = Time.now
      begin
        deliver find_emails
      rescue ActiveRecord::Transactions::TransactionError
      end
      break if @once
      sleep @delay if now + @delay > Time.now
    end
  end

  ##
  # Proxy to ActionMailer::Base#server_settings.  See
  # http://api.rubyonrails.org/classes/ActionMailer/Base.html
  # for instructions on how to configure ActionMailer's SMTP server.

  def server_settings
    ActionMailer::Base.server_settings
  end

end

