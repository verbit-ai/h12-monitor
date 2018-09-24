require 'monitor_logger'

class Dyno
  MAX_ALLOWED_ERROR_COUNT = 10
  MAX_ERRORS_PER_MINUTE = 15
  RESTART_TIMEOUT = ENV.fetch('H12_MONITOR_RESTART_TIMEOUT', 60).to_i # wait for n seconds before next restart.

  def initialize(heroku_connection, app_name, dyno_name)
    @heroku_connection = heroku_connection
    @app_name = app_name
    @name = dyno_name
    @error_count = 0 # Sequent errors count
    @errors = [] # Error timestamps
    @next_restart_at = Time.now
  end

  def handle_h12
    return if Time.now < @next_restart_at
    register_error
    MonitorLogger.warn "#{@name} reports H12 (##{@error_count})"

    if exceeded_error_count? || exceeded_error_rate?
      restart_dyno
      reset_errors
      @next_restart_at = Time.now + RESTART_TIMEOUT
    end
  end

  def reset_errors
    @error_count = 0
    @errors.reject! { |t| t < Time.now - 60 }
  end

  private

  def register_error
    @error_count += 1
    @errors << Time.now
  end

  def exceeded_error_count?
    @error_count >= MAX_ALLOWED_ERROR_COUNT
  end

  def exceeded_error_rate?
    @errors.count >= MAX_ERRORS_PER_MINUTE
  end

  def restart_dyno
    MonitorLogger.warn "restarting dyno #{@name}"
    # `heroku ps:stop -a #{@app_name} #{dyno_name}`
    @heroku_connection.dyno.stop @app_name, @name
    # @heroku_connection.post_ps_restart @app_name, ps: @name
  end
end
