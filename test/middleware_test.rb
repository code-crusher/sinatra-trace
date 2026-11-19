require_relative 'test_helper'

class MiddlewareTest < Minitest::Test
  setup do
    @app = mock_app(Sinatra::Application) do
      get('/*')do
        response.headers['X-Tests'] = env['test.ran'].
          map { |n| n.split('::').last }.
          join(', ')
        env['PATH_INFO']
      end
    end
  end

  class MockMiddleware < Struct.new(:app)
    def call(env)
      (env['test.ran'] ||= []) << self.class.to_s
      app.call(env)
    end
  end

  class UpcaseMiddleware < MockMiddleware
    def call(env)
      env['PATH_INFO'] = env['PATH_INFO'].upcase
      super
    end
  end

  it "is added with Sinatra::Application.use" do
    @app.use UpcaseMiddleware
    get '/hello-world'
    assert ok?
    assert_equal '/HELLO-WORLD', body
  end

  class DowncaseMiddleware < MockMiddleware
    def call(env)
      env['PATH_INFO'] = env['PATH_INFO'].downcase
      super
    end
  end

  it "runs in the order defined" do
    @app.use UpcaseMiddleware
    @app.use DowncaseMiddleware
    get '/Foo'
    assert_equal "/foo", body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "inserts middleware before another middleware with insert_before" do
    @app.use DowncaseMiddleware
    @app.insert_before DowncaseMiddleware, UpcaseMiddleware
    get '/Foo'
    assert_equal "/foo", body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "inserts middleware after another middleware with insert_after" do
    @app.use UpcaseMiddleware
    @app.insert_after UpcaseMiddleware, DowncaseMiddleware
    get '/Foo'
    assert_equal "/foo", body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "inserts middleware at the beginning of the stack with insert_before 0" do
    @app.use DowncaseMiddleware
    @app.insert_before 0, UpcaseMiddleware
    get '/Foo'
    assert_equal "/foo", body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "inserts middleware at the end of the stack with insert_after -1" do
    @app.use UpcaseMiddleware
    @app.insert_after(-1, DowncaseMiddleware)
    get '/Foo'
    assert_equal "/foo", body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "inserts middleware by index with insert_before" do
    @app.use UpcaseMiddleware
    @app.use DowncaseMiddleware
    @app.insert_before 1, FreezeMiddleware
    assert_equal [UpcaseMiddleware, FreezeMiddleware, DowncaseMiddleware],
                 @app.middleware.map(&:first)
  end

  it "inserts middleware by index with insert_after" do
    @app.use UpcaseMiddleware
    @app.use DowncaseMiddleware
    @app.insert_after 0, FreezeMiddleware
    assert_equal [UpcaseMiddleware, FreezeMiddleware, DowncaseMiddleware],
                 @app.middleware.map(&:first)
  end

  it "accepts arguments and a block when inserting middleware" do
    middleware = Class.new(MockMiddleware) do
      attr_reader :args, :block

      def initialize(app, *args, &block)
        super(app)
        @args  = args
        @block = block
      end
    end

    block = proc { 'block' }
    @app.use UpcaseMiddleware
    @app.insert_before UpcaseMiddleware, middleware, 'arg', &block

    _, args, inserted_block = @app.middleware.first
    assert_equal ['arg'], args
    assert_same block, inserted_block
  end

  it "raises an ArgumentError when the target middleware is not in the stack" do
    error = assert_raises(ArgumentError) { @app.insert_before UpcaseMiddleware, DowncaseMiddleware }
    assert_equal "No such middleware to insert before: MiddlewareTest::UpcaseMiddleware", error.message

    error = assert_raises(ArgumentError) { @app.insert_after UpcaseMiddleware, DowncaseMiddleware }
    assert_equal "No such middleware to insert after: MiddlewareTest::UpcaseMiddleware", error.message
  end

  it "raises an ArgumentError when the target index is out of bounds" do
    @app.use UpcaseMiddleware
    error = assert_raises(ArgumentError) { @app.insert_before 2, DowncaseMiddleware }
    assert_equal 'No such middleware to insert before: 2', error.message

    error = assert_raises(ArgumentError) { @app.insert_after(-2, DowncaseMiddleware) }
    assert_equal 'No such middleware to insert after: -2', error.message
  end

  it "can insert before the end of the stack" do
    @app.use UpcaseMiddleware
    @app.insert_before 1, DowncaseMiddleware
    assert_equal [UpcaseMiddleware, DowncaseMiddleware], @app.middleware.map(&:first)
  end

  it "resets the prebuilt pipeline when middleware is inserted" do
    @app.use DowncaseMiddleware
    get '/Foo'
    assert_equal '/foo', body
    @app.insert_before DowncaseMiddleware, UpcaseMiddleware
    get '/Foo'
    assert_equal '/foo', body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "does not modify the middleware of the superclass" do
    base = Sinatra.new(Sinatra::Base) { use DowncaseMiddleware }
    sub  = Sinatra.new(base) { use UpcaseMiddleware }
    sub.insert_after DowncaseMiddleware, FreezeMiddleware

    assert_equal [DowncaseMiddleware], base.middleware.map(&:first)
    assert_equal [DowncaseMiddleware, FreezeMiddleware, UpcaseMiddleware],
                 sub.middleware.map(&:first)
  end

  it "raises an ArgumentError when inserting before inherited middleware" do
    base = Sinatra.new(Sinatra::Base) { use DowncaseMiddleware }
    sub  = Sinatra.new(base)
    error = assert_raises(ArgumentError) { sub.insert_before DowncaseMiddleware, UpcaseMiddleware }
    assert_equal "Cannot insert before MiddlewareTest::DowncaseMiddleware: " \
                 'middleware is inherited from a superclass', error.message
  end

  it "resets the prebuilt pipeline when new middleware is added" do
    @app.use UpcaseMiddleware
    get '/Foo'
    assert_equal "/FOO", body
    @app.use DowncaseMiddleware
    get '/Foo'
    assert_equal '/foo', body
    assert_equal "UpcaseMiddleware, DowncaseMiddleware", response['X-Tests']
  end

  it "works when app is used as middleware" do
    @app.use UpcaseMiddleware
    @app = @app.new
    get '/Foo'
    assert_equal "/FOO", body
    assert_equal "UpcaseMiddleware", response['X-Tests']
  end

  class FreezeMiddleware < MockMiddleware
    def call(env)
      req = Rack::Request.new(env)
      req.update_param('bar', 'baz'.freeze)
      super
    end
  end

  it "works when middleware adds a frozen param" do
    @app.use FreezeMiddleware
    get '/Foo'
  end

  class SpecialConstsMiddleware < MockMiddleware
    def call(env)
      req = Rack::Request.new(env)
      req.update_param('s', :s)
      req.update_param('i', 1)
      req.update_param('c', 3.to_c)
      req.update_param('t', true)
      req.update_param('f', false)
      req.update_param('n', nil)
      super
    end
  end

  it "handles params when the params contains true/false values" do
    @app.use SpecialConstsMiddleware
    get '/'
  end

  class KeywordArgumentInitializationMiddleware < MockMiddleware
    def initialize(app, **)
      super app
    end
  end

  it "handles keyword arguments" do
    @app.use KeywordArgumentInitializationMiddleware, argument: "argument"
    get '/'
  end

  it "handles keyword arguments when inserting middleware" do
    middleware = Class.new(MockMiddleware) do
      attr_reader :options

      def initialize(app, **options)
        super(app)
        @options = options
      end
    end

    @app.use UpcaseMiddleware
    @app.insert_before UpcaseMiddleware, middleware, argument: 'argument'

    _, args, = @app.middleware.first
    assert_equal({ argument: 'argument' }, middleware.new(nil, *args).options)
  end
end
