class HerokuLogStreamer
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  MAX_ALLOWED_ERROR_COUNT = 10
  RETRY_DELAY_BASE = 1

  def initialize(heroku_connection, app_name, heroku_opts={})
    @heroku_connection = heroku_connection
    @app_name = app_name
    @heroku_opts = heroku_opts
    @error_count = 0
  end

  def stream(&block)
    MonitorLogger.info "Connecting to Heroku logplex for #{@app_name}."

    request.start do
      path = heroku_log_url.path + (heroku_log_url.query ? "?" + heroku_log_url.query : "")

      request.request_get(path) do |request|
        buffer = ''
        request.read_body do |chunk|
          @error_count = 0
          buffer << chunk
          while buffer.sub!(/^(.*?)\n/, '')
            puts $1
            yield $1
          end
        end
      end
    end
  rescue Timeout::Error, Errno::ECONNREFUSED, EOFError => e
    @error_count += 1
    if exceeded_error_count?
      MonitorLogger.error error_message(e)
      raise
    else
      MonitorLogger.info error_message(e)
      sleep(RETRY_DELAY_BASE * @error_count**1.5)
      retry
    end
  else
    @error_count = 0
  end

  private

  def heroku_log_url
    @url ||= URI.parse(@heroku_connection.log_session.create(@app_name, @heroku_opts).fetch('logplex_url'))
  end

  def request
    @http ||= Net::HTTP.new(heroku_log_url.host, heroku_log_url.port).tap do |http|
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
    end
  end

  def error_message(e)
    case e
    when Timeout::Error
      "Timeout in Heroku logs (#{e.message})."
    when Errno::ECONNREFUSED
      'Failed to connect to Heroku logplex.'
    when EOFError
      'End of file (EOF) reached.'
    end + " (#{@error_count}) " + (exceeded_error_count? ? 'Retry count exceeded.' : 'Retrying.')
  end

  def exceeded_error_count?
    @error_count >= MAX_ALLOWED_ERROR_COUNT
  end
end
