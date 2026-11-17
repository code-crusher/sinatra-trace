require_relative 'test_helper'

class StreamingTest < Minitest::Test
  Stream = Sinatra::Helpers::Stream

  it 'returns the concatenated body' do
    mock_app do
      get('/') do
        stream do |out|
          out << "Hello" << " "
          out << "World!"
        end
      end
    end

    get('/')
    assert_body "Hello World!"
  end

  it 'always yields strings' do
    stream = Stream.new { |out| out << :foo }
    stream.call(sink = StringIO.new)
    assert_equal 'foo', sink.string
  end

  it 'postpones body generation' do
    step = 0

    stream = Stream.new do |out|
      10.times do
        out << step
        step += 1
      end
    end

    stream.call(sink = StringIO.new)
    assert_equal '0123456789', sink.string
  end

  it 'calls the callback after it is done' do
    step   = 0
    final  = 0
    stream = Stream.new { |_| 10.times { step += 1 } }
    stream.callback { final = step }
    stream.call(StringIO.new)
    assert_equal 10, final
  end

  it 'does not trigger the callback if close is set to :keep_open' do
    step   = 0
    final  = 0
    stream = Stream.new(:keep_open) { |_| 10.times { step += 1 } }
    stream.callback { final = step }
    thread = Thread.new { stream.call(StringIO.new) }
    sleep 0.1
    assert_equal 0, final
    stream.close
    thread.join
  end

  it 'allows adding more than one callback' do
    a = b = false
    stream = Stream.new { }
    stream.callback { a = true }
    stream.callback { b = true }
    stream.call(StringIO.new)
    assert a, 'should trigger first callback'
    assert b, 'should trigger second callback'
  end

  it 'is a Rack 3 callable streaming body' do
    stream = Stream.new { |out| out << 'foo' }
    assert_respond_to stream, :call
    refute_respond_to stream, :each, 'must not respond to #each, or servers ' \
      'would treat it as an Enumerable body instead of a streaming body'
    refute_respond_to stream, :to_ary
  end

  it 'is consumed via #call with the stream the server provides' do
    ran = false
    stream = Stream.new { |out| out << 'foo' }
    stream.call(sink = StringIO.new) { ran = true }
    assert_equal 'foo', sink.string
  end

  it 'closes the stream when the block finishes' do
    stream = Stream.new { |out| out << 'foo' }
    stream.call(sink = StringIO.new)
    assert stream.closed?
    assert_equal 'foo', sink.string
  end

  it 'closes the stream even if the block raises' do
    stream = Stream.new { |out| out << 'foo'; raise 'should be caught' }
    assert_raises(RuntimeError) { stream.call(StringIO.new) }
    assert stream.closed?
  end

  it 'does not trigger an infinite loop if you call close in a callback' do
    stream = Stream.new { |out| out.callback { out.close } }
    stream.call(StringIO.new)
  end

  it 'gives access to route specific params' do
    mock_app do
      get('/:name') do
        stream { |o| o << params[:name] }
      end
    end
    get '/foo'
    assert_body 'foo'
  end

  it 'parks a keep_open stream until it is closed from another thread' do
    stream = Stream.new(:keep_open) { |out| out << 'hi!' }
    sink = StringIO.new
    thread = Thread.new { stream.call(sink) }
    sleep 0.1
    assert_equal 'hi!', sink.string
    refute stream.closed?, 'stream should be kept open'
    stream.close
    thread.join
    assert stream.closed?
  end

  it 'sets up async.close if available' do
    ran = false
    mock_app do
      get('/') do
        close = Object.new
        def close.callback; yield end
        def close.errback; end
        env['async.close'] = close
        stream(:keep_open) do |out|
          out.callback { ran = true }
          out.close
        end
      end
    end
    get '/'
    body # consume the streaming body, as a server would
    assert ran
  end

  it 'has a public interface to inspect its open/closed state' do
    stream = Stream.new { |out| out << :foo }
    assert !stream.closed?
    stream.close
    assert stream.closed?
  end
end
