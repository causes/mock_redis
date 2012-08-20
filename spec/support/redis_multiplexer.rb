class BlankSlate
  instance_methods.each {|m| undef_method(m) unless m =~ /^__/ || ['inspect', 'object_id'].include?(m.to_s)}
end

class RedisMultiplexer < BlankSlate
  MismatchedResponse = Class.new(StandardError)

  def initialize(*a)
    @mock_redis = MockRedis.new(*a)
    @real_redis = Redis.new(*a)
  end

  def method_missing(method, *args, &blk)
    # if we're in a Redis command that accepts a block, and we execute more redis commands, ONLY execute them
    # on the Redis implementation that the block came from. 
    # e.g. if a pipelined command is started on a MockRedis object, DON'T send commands inside the pipelined block
    # to the real Redis object, as that one WON'T be inside a pipelined command, and we'll see weird behaviour
    if blk
      @in_mock_block  = true
      @in_redis_block = false
    end
    mock_retval, mock_error = catch_errors { @in_redis_block ? :no_op : @mock_redis.send(method, *args, &blk) }

    if blk
      @in_mock_block  = false
      @in_redis_block = true
    end
    real_retval, real_error = catch_errors { @in_mock_block ? :no_op : @real_redis.send(method, *args, &blk) }

    if blk
      @in_mock_block  = false
      @in_redis_block = false
    end

    mock_retval = handle_special_cases(method, mock_retval)
    real_retval = handle_special_cases(method, real_retval)

    if (mock_retval == :no_op || real_retval == :no_op)
        # ignore, we were inside a block (like pipelined)
    elsif (!equalish?(mock_retval, real_retval) && !mock_error && !real_error)
      # no exceptions, just different behavior
      raise MismatchedResponse,
        "Mock failure: responses not equal.\n" +
        "Redis.#{method}(#{args.inspect}) returned #{real_retval.inspect}\n" +
        "MockRedis.#{method}(#{args.inspect}) returned #{mock_retval.inspect}\n"
    elsif (!mock_error && real_error)
      raise MismatchedResponse,
        "Mock failure: didn't raise an error when it should have.\n" +
        "Redis.#{method}(#{args.inspect}) raised #{real_error.inspect}\n" +
        "MockRedis.#{method}(#{args.inspect}) raised nothing " +
        "and returned #{mock_retval.inspect}"
    elsif (!real_error && mock_error)
      raise MismatchedResponse,
        "Mock failure: raised an error when it shouldn't have.\n" +
        "Redis.#{method}(#{args.inspect}) returned #{real_retval.inspect}\n" +
        "MockRedis.#{method}(#{args.inspect}) raised #{mock_error.inspect}"
    elsif (mock_error && real_error && !equalish?(mock_error, real_error))
      raise MismatchedResponse,
        "Mock failure: raised the wrong error.\n" +
        "Redis.#{method}(#{args.inspect}) raised #{real_error.inspect}\n" +
        "MockRedis.#{method}(#{args.inspect}) raised #{mock_error.inspect}"
    end

    raise mock_error if mock_error
    mock_retval
  end

  def equalish?(a, b)
    if a == b
      true
    elsif a.is_a?(Array) && b.is_a?(Array)
      a.zip(b).all? {|(x,y)| equalish?(x,y)}
    elsif a.is_a?(Exception) && b.is_a?(Exception)
      a.class == b.class && a.message == b.message
    else
      false
    end
  end

  def mock() @mock_redis end
  def real() @real_redis end

  # Some commands require special handling due to nondeterminism in
  # the returned values.
  def handle_special_cases(method, value)
    case method.to_s
    when 'keys', 'hkeys', 'sdiff', 'sinter', 'smembers', 'sunion'
      # The order is irrelevant, but [a,b] != [b,a] in Ruby, so we
      # sort the returned values so we can ignore the order.
      value.sort if value
    else
      value
    end
  end

  # Used in cleanup before() blocks.
  def send_without_checking(method, *args)
    @mock_redis.send(method, *args)
    @real_redis.send(method, *args)
  end

  def catch_errors
    begin
      retval = yield
      [retval, nil]
    rescue StandardError => e
      [nil, e]
    end
  end
end

