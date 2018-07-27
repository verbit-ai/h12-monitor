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
      allow(logger).to receive(:info)
      streamer.stream
    end

    it 'should connect to the correct URI' do
      expect(logs_request).to have_been_requested
    end

    it 'should log a connection message' do
      expect(logger).to have_received(:info).with('Connecting to Heroku logplex for myapp.')
    end

    skip 'should yield with log line'
    skip 'should retry on timeout error'
    skip 'should retry on connection error'
    skip 'should retry on end of file error'
  end

  private

  def stub_logger
    double(Logger).tap do |logger|
      allow(MonitorLogger).to receive_message_chain :instance, logger: logger
    end
  end
end
