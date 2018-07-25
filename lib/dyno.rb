require 'monitor_logger'

class Dyno
  MAX_ALLOWED_ERROR_COUNT = 3

  def initialize(heroku_connection, app_name, dyno_name)
    @heroku_connection = heroku_connection
    @app_name = app_name
    @name = dyno_name
    @error_count = 0
    @next_restart_at = Time.now
  end

  def handle_h12
    return if Time.now < @next_restart_at
    add_to_error_count
    MonitorLogger.warn "#{@name} reports H12 (##{@error_count})"

    if exceeded_error_count?
      restart_dyno
      reset_error_count
      @next_restart_at = 30.seconds.from_now # ignoring errors for 30 seconds after restart.
    end
  end

  def reset_error_count
    @error_count = 0
  end

  private

  def add_to_error_count
    @error_count += 1
  end

  def exceeded_error_count?
    @error_count >= MAX_ALLOWED_ERROR_COUNT
  end

  def restart_dyno
    MonitorLogger.warn "restarting dyno #{@name}"
    # `heroku ps:stop -a #{@app_name} #{dyno_name}`
    @heroku_connection.dyno.stop @app_name, @name
    # @heroku_connection.post_ps_restart @app_name, ps: @name
  end
end
