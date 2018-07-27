require 'spec_helper'
require 'dyno'

RSpec.describe Dyno do
  context 'MAX_ALLOWED_ERROR_COUNT' do
    it 'should be the correct value' do
      expect(Dyno::MAX_ALLOWED_ERROR_COUNT).to eq(10)
    end
  end

  context 'when a dyno reports an H12' do
    let(:heroku_connection) { PlatformAPI.connect('fake_api_key') }
    let(:dyno) { Dyno.new(heroku_connection, 'myapp', 'web.1') }
    let!(:request) {
      stub_request(:post, 'https://api.heroku.com/apps/myapp/dynos/web.1/actions/stop')
        .to_return(status: 200)
    }

    context 'and this is the first reported error' do
      before { dyno.handle_h12 }

      it 'should not restart the dyno' do
        expect(request).not_to have_been_requested
      end
    end

    context 'and this is the max allowed error' do
      before do
        Dyno::MAX_ALLOWED_ERROR_COUNT.times do
          dyno.handle_h12
        end
      end

      it 'should restart the dyno' do
        expect(request).to have_been_requested
      end
    end
  end
end
