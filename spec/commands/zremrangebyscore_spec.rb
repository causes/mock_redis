require 'spec_helper'
require 'date'

RSpec.describe '#zremrangebyscore(key, min, max)' do
  before do
    @key = 'mock-redis-test:zremrangebyscore'
    @redises.zadd(@key, 1, 'Washington')
    @redises.zadd(@key, 2, 'Adams')
    @redises.zadd(@key, 3, 'Jefferson')
    @redises.zadd(@key, 4, 'Madison')
  end

  it 'returns the number of elements in range' do
    expect(@redises.zremrangebyscore(@key, 2, 3)).to eq(2)
  end

  it 'removes the elements' do
    @redises.zremrangebyscore(@key, 2, 3)
    expect(@redises.zrange(@key, 0, -1)).to eq(%w[Washington Madison])
  end

  # As seen in http://redis.io/commands/zremrangebyscore
  it 'removes the elements for complex statements' do
    @redises.zremrangebyscore(@key, '-inf', '(4')
    expect(@redises.zrange(@key, 0, -1)).to eq(%w[Madison])
  end

  it_should_behave_like 'a zset-only command'

  it 'throws a type error' do
    expect do
      @redises.zrevrangebyscore(@key, DateTime.now, '-inf')
    end.to raise_error(TypeError)
  end
end
