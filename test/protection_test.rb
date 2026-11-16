# frozen_string_literal: true

require_relative 'test_helper'

# Tests for the default Rack::Protection setup (see #2012): the default-on
# protections have to actually reject malicious requests instead of merely
# dropping the session and letting the request through to the application.
class ProtectionTest < Minitest::Test
  it 'denies cross-origin POST requests by default' do
    mock_app do
      enable :sessions

      post('/') { "route executed" }
    end

    post '/', {}, 'HTTP_ORIGIN' => 'http://malicious.example'

    assert_equal 403, response.status
    assert_equal 'Forbidden', body
  end

  it 'denies requests with a spoofed IP by default' do
    mock_app do
      get('/') { "route executed" }
    end

    get '/', {},
      'HTTP_X_FORWARDED_FOR' => '1.2.3.4',
      'HTTP_CLIENT_IP' => '6.6.6.6'

    assert_equal 403, response.status
  end

  it 'lets safe requests pass' do
    mock_app do
      enable :sessions

      get('/') { "ok" }
    end

    get '/', {}, 'HTTP_USER_AGENT' => 'Mozilla/5.0'

    assert_equal 200, response.status
    assert_equal 'ok', body
  end

  it 'lets same-origin unsafe requests pass' do
    mock_app do
      enable :sessions

      post('/') { "ok" }
    end

    post '/', {}, 'HTTP_ORIGIN' => 'http://example.org'

    assert_equal 200, response.status
    assert_equal 'ok', body
  end

  it 'allows opting into the drop_session reaction' do
    mock_app do
      set :protection, :reaction => :drop_session

      post('/') { "route executed" }
    end

    session = { 'foo' => 'bar' }
    post '/', {}, 'rack.session' => session, 'HTTP_ORIGIN' => 'http://malicious.example'

    assert_equal 200, response.status
    assert_equal 'route executed', body
    assert_empty session
  end

  it 'allows opting into a custom reaction per protection' do
    mock_app do
      set :protection, :except => :http_origin

      post('/') { "ok" }
    end

    post '/', {}, 'HTTP_ORIGIN' => 'http://malicious.example'

    assert_equal 200, response.status
    assert_equal 'ok', body
  end
end
