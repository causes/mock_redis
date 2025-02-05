require 'spec_helper'

RSpec.describe '#sunion(key [, key, ...])' do
  before do
    @evens   = 'mock-redis-test:sunion:evens'
    @primes  = 'mock-redis-test:sunion:primes'

    [2, 4, 6, 8, 10].each { |i| @redises.sadd(@evens, i) }
    [2, 3, 5, 7].each { |i| @redises.sadd(@primes, i) }
  end

  it 'returns the elements in the resulting set' do
    expect(@redises.sunion(@evens, @primes)).to eq(%w[2 4 6 8 10 3 5 7])
  end

  it 'treats missing keys as empty sets' do
    expect(@redises.sunion(@primes, 'mock-redis-test:nonesuch')).
      to eq(%w[2 3 5 7])
  end

  it 'allows Array as argument' do
    expect(@redises.sunion([@evens, @primes])).to eq(%w[2 4 6 8 10 3 5 7])
  end

  it 'raises an error if given 0 sets' do
    expect do
      @redises.sunion
    end.to raise_error(Redis::CommandError)
  end

  it 'raises an error if any argument is not a a set' do
    @redises.set('mock-redis-test:notset', 1)

    expect do
      @redises.sunion(nil, 'mock-redis-test:notset')
    end.to raise_error(TypeError)

    expect do
      @redises.sunion('mock-redis-test:notset', nil)
    end.to raise_error(TypeError)
  end
end
