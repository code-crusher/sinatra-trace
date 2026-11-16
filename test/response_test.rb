require_relative 'test_helper'

class ResponseTest < Minitest::Test
  setup { @response = Sinatra::Response.new([], 200, { 'Content-Type' => 'text/html' }) }

  def assert_same_body(a, b)
    assert_equal a.to_enum(:each).to_a, b.to_enum(:each).to_a
  end

  it "initializes with 200, text/html, and empty body" do
    assert_equal 200, @response.status
    assert_equal 'text/html', @response['Content-Type']
    assert_equal [], @response.body
  end

  it 'uses case insensitive headers' do
    @response['content-type'] = 'application/foo'
    assert_equal 'application/foo', @response['Content-Type']
    assert_equal 'application/foo', @response['CONTENT-TYPE']
  end

  it 'writes to body' do
    @response.body = 'Hello'
    @response.write ' World'
    assert_equal 'Hello World', @response.body.join
  end

  [204, 304].each do |status_code|
    it "removes the Content-Type header and body when response status is #{status_code}" do
      @response.status = status_code
      @response.body = ['Hello World']
      assert_equal [status_code, {}, []], @response.finish
    end
  end

  [200, 201, 202, 301, 302, 400, 401, 403, 404, 500].each do |status_code|
    it "will not removes the Content-Type header and body when response status
        is #{status_code}" do
      @response.status = status_code
      @response.body   = ['Hello World']
      assert_equal [
        status_code,
        { 'content-type' => 'text/html', 'content-length' => '11' },
        ['Hello World']
      ], @response.finish
    end
  end

  it 'Calculates the Content-Length using the bytesize of the body' do
    @response.body = ['Hello', 'World!', '✈']
    _, headers, body = @response.finish
    assert_equal '14', headers['Content-Length']
    assert_same_body @response.body, body
  end

  it 'does not call #to_ary or #inject on the body' do
    object = Object.new
    def object.inject(*) fail 'called' end
    def object.to_ary(*) fail 'called' end
    def object.each(*) end
    @response.body = object
    assert @response.finish
  end

  it 'keeps the Content-Length header when a body is assigned to a fresh response' do
    @response['Content-Length'] = '5'
    @response.body = 'Hello'
    _, headers, = @response.finish
    assert_equal '5', headers['content-length']
  end

  it 'invalidates the Content-Length header when the body is replaced' do
    @response.body = 'Hello'
    @response['Content-Length'] = '5'
    @response.body = 'Goodbye'
    _, headers, = @response.finish
    assert_equal '7', headers['content-length']
  end

  it 'invalidates the Content-Length header when a written body is replaced' do
    @response.write 'Hello'
    @response['Content-Length'] = '5'
    @response.body = 'Hi'
    _, headers, = @response.finish
    assert_equal '2', headers['content-length']
  end

  it 'keeps the Content-Length header when assigning the same body object' do
    stream = Object.new
    def stream.each; end
    @response.body = stream
    @response['Content-Length'] = '46'
    @response.body = stream
    _, headers, = @response.finish
    assert_equal '46', headers['content-length']
  end

  it 'calculates the Content-Length header when the body is replaced with an empty one' do
    @response.body = 'Hello'
    @response['Content-Length'] = '5'
    @response.body = ''
    _, headers, = @response.finish
    assert_equal '0', headers['content-length']
  end

  it 'does not nest a Sinatra::Response' do
    @response.body = Sinatra::Response.new ["foo"]
    assert_same_body @response.body, ["foo"]
  end

  it 'does not nest a Rack::Response' do
    @response.body = Rack::Response.new ["foo"]
    assert_same_body @response.body, ["foo"]
  end
end
