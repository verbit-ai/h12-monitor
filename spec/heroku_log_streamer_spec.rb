require 'spec_helper'
require 'heroku_log_streamer'
require 'json'

RSpec.describe HerokuLogStreamer do
  context 'OPEN_TIMEOUT' do
    it 'should be expected' do
      expect(HerokuLogStreamer::OPEN_TIMEOUT).to eq(5)
    end
  end

  context 'READ_TIMEOUT' do
    it 'should be expected' do
      expect(HerokuLogStreamer::READ_TIMEOUT).to eq(10)
    end
  end

  context 'stream' do
    let(:heroku_logs_uri) { 'https://api.heroku.com/apps/myapp/logs?logplex=true&tail=1' }
    let(:heroku_connection) { PlatformAPI.connect('fake_api_key') }
    let!(:log_session_request) {
      stub_request(:post, 'https://api.heroku.com/apps/myapp/log-sessions')
        .with(body: {'tail' => '1'})
        .to_return(
          status: 200,
          body: {logplex_url: heroku_logs_uri}.to_json,
          headers: {'Content-Type' => 'application/json'}
        )
    }
    let!(:logs_request) { stub_request(:get, heroku_logs_uri).to_return(status: 200) }
    let!(:logger) { stub_logger }
    let(:streamer) { HerokuLogStreamer.new(heroku_connection, 'myapp', tail: '1') }

    before do
      stub_const("#{described_class.name}::RETRY_DELAY_BASE", 0)
      allow(logger).to receive(:info)
    end

    it 'should connect to the correct URI' do
      streamer.stream
      expect(logs_request).to have_been_requested
    end

    it 'should log a connection message' do
      streamer.stream
      expect(logger).to have_received(:info).with('Connecting to Heroku logplex for myapp.')
    end

    skip 'should yield with log line'

    shared_examples 'retry on error' do |error, message|
      let(:http) { instance_double(Net::HTTP) }

      context 'on max errors' do
        before do
          expect(http).to receive(:start).and_raise(error, 'Error message').exactly(described_class::MAX_ALLOWED_ERROR_COUNT).times
          expect(streamer).to receive(:request).and_return(http).at_least(:once)
          allow(logger).to receive(:error)
        end

        it 'should log "error" and fail' do
          expect(logger).to receive(:info).at_least(:once)
          expect(logger).to receive(:error).with(message + " (#{described_class::MAX_ALLOWED_ERROR_COUNT}) Retry count exceeded.").once

          expect {streamer.stream}.to raise_error error
          expect(streamer.instance_variable_get(:@error_count)).to eq described_class::MAX_ALLOWED_ERROR_COUNT
        end
      end

      context 'on one error' do
        before do
          expect(http).to receive(:start).and_raise(error, 'Error message').once
          expect(http).to receive(:start).and_return(nil).once
          expect(streamer).to receive(:request).and_return(http).at_least(:once)
        end

        it 'should log "info", retry and reset error count on success' do
          expect(logger).to receive(:info).with(message + " (1) Retrying.").once
          expect(logger).not_to receive(:error)

          streamer.stream
          expect(streamer.instance_variable_get(:@error_count)).to eq 0
        end
      end
    end

    context 'timeout error' do
      include_examples 'retry on error', Timeout::Error, "Timeout in Heroku logs (Error message)."
    end

    context 'connection error' do
      include_examples 'retry on error', Errno::ECONNREFUSED, 'Failed to connect to Heroku logplex.'
    end

    context 'file error' do
      include_examples 'retry on error', EOFError, 'End of file (EOF) reached.'
    end
  end

  private

  def stub_logger
    double(Logger).tap do |logger|
      allow(MonitorLogger).to receive_message_chain :instance, logger: logger
    end
  end
end
