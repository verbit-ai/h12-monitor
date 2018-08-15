require 'singleton'
require 'uri'
require 'net/http'
require 'logger'

class MonitorLogger
  include Singleton

  WEBHOOK_URL = ENV['H12_MONITOR_WEBHOOK_URL']

  attr_accessor :logger

  def initialize
    self.logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
  end

  def self.info(message)
    logger.info message
  end

  def self.warn(message)
    logger.warn message
    notify_team message
  end

  def self.error(message)
    logger.error message
    notify_team message
  end

  private

  def self.logger
    MonitorLogger.instance.logger
  end

  def self.notify_team(text)
    return unless WEBHOOK_URL
    uri = URI(WEBHOOK_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    req = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
    req.body = {text: text}.to_json
    res = http.request(req)
    MonitorLogger.info "Team notification response: #{res.body}"
  rescue => e
    MonitorLogger.info "Team notification failed: #{e}"
  end
end
