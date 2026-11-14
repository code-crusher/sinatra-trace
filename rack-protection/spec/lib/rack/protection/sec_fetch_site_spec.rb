# frozen_string_literal: true

RSpec.describe Rack::Protection::SecFetchSite do
  it_behaves_like 'any rack application'

  def request(method, headers = {})
    if respond_to?(method.downcase)
      send(method.downcase, '/', {}, headers)
    else
      custom_request(method, '/', {}, headers)
    end
  end

  before(:each) do
    mock_app do
      use Rack::Protection::SecFetchSite
      run DummyApp
    end
  end

  %w[GET HEAD OPTIONS TRACE].each do |method|
    it "accepts #{method} requests regardless of the Sec-Fetch-Site header" do
      %w[same-origin same-site cross-site none].each do |value|
        expect(request(method, 'HTTP_SEC_FETCH_SITE' => value)).to be_ok
      end
    end
  end

  %w[POST PUT PATCH DELETE].each do |method|
    it "accepts #{method} requests with a same-origin Sec-Fetch-Site header" do
      expect(request(method, 'HTTP_SEC_FETCH_SITE' => 'same-origin')).to be_ok
    end

    it "accepts #{method} requests with a none Sec-Fetch-Site header" do
      expect(request(method, 'HTTP_SEC_FETCH_SITE' => 'none')).to be_ok
    end

    it "denies #{method} requests with a cross-site Sec-Fetch-Site header" do
      expect(request(method, 'HTTP_SEC_FETCH_SITE' => 'cross-site')).not_to be_ok
    end

    it "denies #{method} requests with a same-site Sec-Fetch-Site header" do
      expect(request(method, 'HTTP_SEC_FETCH_SITE' => 'same-site')).not_to be_ok
    end

    it "denies #{method} requests with an unrecognized Sec-Fetch-Site header" do
      expect(request(method, 'HTTP_SEC_FETCH_SITE' => 'bogus')).not_to be_ok
    end

    it "accepts #{method} requests without a Sec-Fetch-Site header by default" do
      expect(request(method)).to be_ok
    end
  end

  context 'with allow_missing: false' do
    before(:each) do
      mock_app do
        use Rack::Protection::SecFetchSite, allow_missing: false
        run DummyApp
      end
    end

    %w[GET HEAD OPTIONS TRACE].each do |method|
      it "accepts #{method} requests without a Sec-Fetch-Site header" do
        expect(request(method)).to be_ok
      end
    end

    %w[POST PUT PATCH DELETE].each do |method|
      it "denies #{method} requests without a Sec-Fetch-Site header" do
        expect(request(method)).not_to be_ok
      end

      it "accepts #{method} requests with a same-origin Sec-Fetch-Site header" do
        expect(request(method, 'HTTP_SEC_FETCH_SITE' => 'same-origin')).to be_ok
      end

      it "denies #{method} requests with a cross-site Sec-Fetch-Site header" do
        expect(request(method, 'HTTP_SEC_FETCH_SITE' => 'cross-site')).not_to be_ok
      end
    end
  end

  context 'with allow_if' do
    before(:each) do
      mock_app do
        use Rack::Protection::SecFetchSite,
            allow_missing: false,
            allow_if: ->(env) { env['PATH_INFO'].start_with?('/webhooks/') }
        run DummyApp
      end
    end

    it 'accepts cross-site requests for paths permitted by allow_if' do
      post('/webhooks/foo', {}, 'HTTP_SEC_FETCH_SITE' => 'cross-site')
      expect(last_response).to be_ok
    end

    it 'denies cross-site requests for other paths' do
      post('/other', {}, 'HTTP_SEC_FETCH_SITE' => 'cross-site')
      expect(last_response).not_to be_ok
    end

    it 'accepts requests without a Sec-Fetch-Site header for paths permitted by allow_if' do
      post('/webhooks/foo')
      expect(last_response).to be_ok
    end

    it 'denies requests without a Sec-Fetch-Site header for other paths' do
      post('/other')
      expect(last_response).not_to be_ok
    end
  end
end
