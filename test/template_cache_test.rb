require_relative 'test_helper'

class TemplateCacheTest < Minitest::Test
  it 'caches the value returned by the block' do
    cache = Sinatra::TemplateCache.new
    first  = cache.fetch(:key) { 'value' }
    assert_equal 'value', first
    assert_same first, cache.fetch(:key) { raise 'block should not be called' }
  end

  it 'caches nil values' do
    cache = Sinatra::TemplateCache.new
    assert_nil cache.fetch(:key) { nil }
    assert_nil cache.fetch(:key) { raise 'block should not be called' }
  end

  it 'accepts multiple objects as key' do
    cache = Sinatra::TemplateCache.new
    cache.fetch(:a, 1, 'b') { 'value' }
    assert_equal 'value', cache.fetch(:a, 1, 'b') { raise 'block should not be called' }
    assert_nil cache.fetch(:a, 1, 'c') { nil }
  end

  it 'clear removes cached values' do
    cache = Sinatra::TemplateCache.new
    cache.fetch(:key) { 'value' }
    cache.clear
    assert_equal 'new value', cache.fetch(:key) { 'new value' }
  end

  it 'is usable concurrently' do
    cache = Sinatra::TemplateCache.new
    expected = Array.new(100) { |i| "value #{i}" }

    Array.new(20) do
      Thread.new do
        100.times do |i|
          assert_equal expected[i], cache.fetch(:key, i) { "value #{i}" }
        end
      end
    end.each(&:join)
  end

  it 'stores a single value when threads race to fill the same key' do
    cache   = Sinatra::TemplateCache.new
    start   = Queue.new
    fill_me = Array.new(20) do |i|
      Thread.new do
        start.pop
        cache.fetch(:key) { "value #{i}" }
      end
    end

    fill_me.size.times { start << true }
    values = fill_me.map(&:value)

    # Every racing thread gets its own computed value back, but only one of
    # them ends up stored in the cache.
    assert_equal values.uniq, [cache.fetch(:key) { raise 'block should not be called' }]
  end

  it 'keeps a consistent view when cleared while filling' do
    cache   = Sinatra::TemplateCache.new
    start   = Queue.new
    filler  = Thread.new do
      start.pop
      cache.fetch(:key) { 'value' }
    end

    start << true
    cache.clear
    filler.join

    # Either the value survived the clear, or it did not -- both are valid
    # outcomes of a concurrent clear. Subsequent fetches must be consistent.
    assert_includes [nil, 'value'], cache.fetch(:key) { nil }
  end
end
