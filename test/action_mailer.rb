require 'net/smtp'
require 'time'

class Net::SMTP

  @reset_called = 0

  @deliveries = []

  @send_message_block = nil

  class << self

    attr_reader :deliveries
    attr_reader :send_message_block
    attr_accessor :reset_called

    alias old_start start

  end

  def self.start(*args)
    yield new(nil)
  end

  def self.on_send_message(&block)
    @send_message_block = block
  end

  def self.reset
    deliveries.clear
    on_send_message
    @reset_called = 0
  end

  alias old_reset reset if instance_methods.include? 'reset'

  def reset
    self.class.reset_called += 1
  end

  alias old_send_message send_message

  def send_message(mail, to, from)
    return self.class.send_message_block.call(mail, to, from) unless
      self.class.send_message_block.nil?
    self.class.deliveries << [mail, to, from]
    return "queued"
  end

end

##
# Stub for ActionMailer::Base

module ActionMailer; end

class ActionMailer::Base

  @server_settings = {}

  def self.logger
    o = Object.new
    def o.info(arg) end
    return o
  end

  def self.method_missing(meth, *args)
    meth.to_s =~ /deliver_(.*)/
    super unless $1
    new($1, *args).deliver!
  end

  def self.reset
    server_settings.clear
  end

  def self.server_settings
    @server_settings
  end

  def initialize(meth = nil)
    send meth if meth
  end

  def deliver!
    perform_delivery_activerecord @mail
  end

end

##
# Stub for an ActiveRecord model

class Email

  START = Time.parse 'Thu Aug 10 11:19:48'

  attr_accessor :from, :to, :mail, :last_send_attempt, :created_on, :id

  @records = []
  @id = 0

  class << self; attr_accessor :records, :id; end

  def self.create(record)
    record = new record[:from], record[:to], record[:mail]
    records << record
    return record
  end

  def self.find(_, conditions = nil)
    return records if conditions.nil?
    now = Time.now.to_i - 300
    return records.select do |r|
      r.last_send_attempt < now
    end
  end

  def self.reset
    @id = 0
    records.clear
  end

  def initialize(from, to, mail)
    @from = from
    @to = to
    @mail = mail
    @id = self.class.id += 1
    @created_on = START + @id
    @last_send_attempt = 0
  end

  def destroy
    self.class.records.delete self
    self.freeze
  end

  def ==(other)
    other.id == id
  end

  def save
  end

end

class String
  def classify
    self
  end

  def tableize
    self.downcase
  end

end

