require 'spec_helper'

RSpec.describe Sinatra::Extension do
  module ExampleExtension
    extend Sinatra::Extension

    set :foo, :bar
    settings.set :bar, :blah

    configure :test, :production do
      set :reload_stuff, false
    end

    configure :development do
      set :reload_stuff, true
    end

    get '/' do
      "from extension, yay"
    end
  end

  before { mock_app { register ExampleExtension }}

  it('allows using set') { expect(settings.foo).to eq(:bar) }
  it('implements configure') { expect(settings.reload_stuff).to be false }

  it 'allows defing routes' do
    expect(get('/')).to be_ok
    expect(body).to eq("from extension, yay")
  end

  describe 'middleware with keyword arguments' do
    class KeywordLogger
      def initialize(app, level: :info)
        @app, @level = app, level
      end

      def call(env)
        status, headers, body = @app.call(env)
        headers['X-Level'] = @level.to_s
        [status, headers, body]
      end
    end

    module KeywordLoggerExtension
      extend Sinatra::Extension

      use KeywordLogger, level: :debug
    end

    it 'does not collapse keyword arguments into a positional hash' do
      mock_app do
        register KeywordLoggerExtension
        get('/') { 'ok' }
      end

      expect(get('/')).to be_ok
      expect(last_response.headers['X-Level']).to eq('debug')
    end
  end
end
