require 'spec_helper'

RSpec.describe MonitorLogger do
  before do
    @logger = double(Logger)
    allow(Logger).to receive_messages new: @logger
    allow(MonitorLogger).to receive_message_chain :instance, logger: @logger
  end

  after do
    allow(Logger).to receive(:new).and_call_original
  end

  context 'info' do
    before do
      stub_log_method @logger, :info
    end

    it 'logs an info message' do
      expect(@logger).to have_received(:info).with('info message')
    end
  end

  context 'warn' do
    before do
      stub_log_method @logger, :warn
    end

    it 'logs a warning message' do
      expect(@logger).to have_received(:warn).with('warn message')
    end
  end

  context 'error' do
    before do
      stub_log_method @logger, :error
    end

    it 'logs an error message' do
      expect(@logger).to have_received(:error).with('error message')
    end
  end

  private

  def stub_log_method(stub, method_name)
    allow(stub).to receive method_name
    MonitorLogger.send method_name, "#{method_name} message"
  end
end
