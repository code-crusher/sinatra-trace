require 'multi_json'

require 'spec_helper'
require 'okjson'

RSpec.shared_examples_for "a json encoder" do |lib, const|
  before do
    begin
      require lib if lib
      @encoder = eval(const)
    rescue LoadError
      skip "unable to load #{lib}"
    end
  end

  it "allows setting :encoder to #{const}" do
    enc = @encoder
    mock_app { get('/') { json({'foo' => 'bar'}, :encoder => enc) }}
    results_in 'foo' => 'bar'
  end

  it "allows setting settings.json_encoder to #{const}" do
    enc = @encoder
    mock_app do
      set :json_encoder, enc
      get('/') { json 'foo' => 'bar' }
    end
    results_in 'foo' => 'bar'
  end
end

RSpec.describe Sinatra::JSON do
  def mock_app(&block)
    super do
      class_eval(&block)
    end
  end

  def results_in(obj)
    expect(OkJson.decode(get('/').body)).to eq(obj)
  end

  it "encodes objects to json out of the box" do
    mock_app { get('/') { json :foo => [1, 'bar', nil] } }
    results_in 'foo' => [1, 'bar', nil]
  end

  it "uses the canonical multi_json constant as the default encoder" do
    # multi_json 1.21 renamed the MultiJson constant to MultiJSON and
    # deprecated the old name (issue #2170).  The default encoder must be
    # whichever constant is canonical for the installed version.
    canonical = defined?(::MultiJSON) ? ::MultiJSON : ::MultiJson
    mock_app { get('/') { json :foo => 'bar' } }
    expect(settings.json_encoder).to eq canonical
  end

  it "encodes objects with Sinatra::JSON.encode" do
    canonical = defined?(::MultiJSON) ? ::MultiJSON : ::MultiJson
    expect(Sinatra::JSON.encode(:foo => [1, 'bar', nil]))
      .to eq canonical.dump(:foo => [1, 'bar', nil])
  end

  it "prefers generate over encode when the encoder offers both" do
    # multi_json >= 1.21 keeps #encode around as a deprecated alias for
    # #generate; the former must not be used when both are available.
    enc = Object.new
    def enc.generate(_obj) 'from generate' end
    def enc.encode(_obj) 'from encode' end
    mock_app do
      set :json_encoder, enc
      get('/') { json 42 }
    end
    expect(get('/').body).to eq('from generate')
  end

  it "emits no multi_json deprecation warnings in the default flow" do
    # Canary for issue #2170: with multi_json >= 1.21 installed, the
    # deprecated MultiJson constant and encode/dump methods must never be
    # reached.  With older versions no multi_json warning exists at all.
    warnings = []
    allow(Warning).to receive(:warn) { |*args| warnings << args.first }
    mock_app { get('/') { json :foo => [1, 'bar', nil] } }
    results_in 'foo' => [1, 'bar', nil]
    expect(warnings.join("\n")).not_to match(/multi_?json/i)
  end

  it "sets the content type to 'application/json'" do
    mock_app { get('/') { json({}) } }
    expect(get('/')["Content-Type"]).to include("application/json")
  end

  it "allows overriding content type with :content_type" do
    mock_app { get('/') { json({}, :content_type => "foo/bar") } }
    expect(get('/')["Content-Type"]).to eq("foo/bar")
  end

  it "accepts shorthands for :content_type" do
    mock_app { get('/') { json({}, :content_type => :js) } }
    # Changed to "text/javascript" in Rack >3.0
    # https://github.com/sinatra/sinatra/pull/1857#issuecomment-1445062212
    expect(get('/')["Content-Type"])
      .to eq("application/javascript;charset=utf-8").or eq("text/javascript;charset=utf-8")
  end

  it 'calls generate on :encoder if available' do
    enc = Object.new
    def enc.generate(obj) obj.inspect end
    mock_app { get('/') { json(42, :encoder => enc) }}
    expect(get('/').body).to eq('42')
  end

  it 'calls encode on :encoder if available' do
    enc = Object.new
    def enc.encode(obj) obj.inspect end
    mock_app { get('/') { json(42, :encoder => enc) }}
    expect(get('/').body).to eq('42')
  end

  it 'sends :encoder as method call if it is a Symbol' do
    mock_app { get('/') { json(42, :encoder => :inspect) }}
    expect(get('/').body).to eq('42')
  end

  it 'calls generate on settings.json_encoder if available' do
    enc = Object.new
    def enc.generate(obj) obj.inspect end
    mock_app do
      set :json_encoder, enc
      get('/') { json 42 }
    end
    expect(get('/').body).to eq('42')
  end

  it 'calls encode on settings.json_encode if available' do
    enc = Object.new
    def enc.encode(obj) obj.inspect end
    mock_app do
      set :json_encoder, enc
      get('/') { json 42 }
    end
    expect(get('/').body).to eq('42')
  end

  it 'sends settings.json_encode  as method call if it is a Symbol' do
    mock_app do
      set :json_encoder, :inspect
      get('/') { json 42 }
    end
    expect(get('/').body).to eq('42')
  end

  describe('Yajl')    { it_should_behave_like "a json encoder", "yajl", "Yajl::Encoder" } unless defined? JRUBY_VERSION
  describe('JSON')    { it_should_behave_like "a json encoder", "json", "::JSON"        }
  describe('OkJson')  { it_should_behave_like "a json encoder", nil,    "OkJson"        }
  describe('to_json') { it_should_behave_like "a json encoder", "json", ":to_json"      }
  describe('without') { it_should_behave_like "a json encoder", nil,    "Sinatra::JSON" }
end
