module RelationalRedisMapper
  class Redis

    attr_reader :redis, :serializer

    class << self

      def get(opt={})
        @singleton ||= new(opt)
      end
      alias_method :set, :get

    end

    def add_query_index(key,val)
      redis.lpush key, val
    end

    def find_id(key)
      redis.lindex key, 0
    end

    def find_ids(key)
      redis.lrange(key, 0, -1).flatten
    end

    def find_object(class_key, object_key)
      deserialize redis.hget(class_key, object_key) rescue nil
    end
      
    def find_objects(key, ids)
      redis.hmget(key, ids).map { |str| deserialize(str) } rescue []
    end

    def all_objects(key)
      redis.hgetall(key).values.map { |str| deserialize(str) }
    end

    def rm_search_index(key,val)
      redis.lrem key,1,val
    end

    def add_uniq_index(key,val)
      redis.set key, val
    end

    def rm_uniq_index(key)
      redis.del key
    end

    def get_uniq_index(key)
      redis.get key
    end

    def save_object(*args)
      object = args.pop
      redis.hset *args, serialize(object)
    end

    def delete_object(*args)
      redis.hdel *args
    end

    def remove_indices
      query_keys.each { |attr| redis.lrem search_key(attr, send(attr)),1, uuid }
      uniqueness_attr.each { |attr| redis.del uniq_key(attr, send(attr)) }
    end
    
    def method_missing(method, *args, &block)
      redis.send method, *args, &block
    end

    def serialize(object)
      serializer.dump(object)
    end

    def deserialize(stringified)
      serializer.restore stringified
    end

    private

    def initialize(opt)
      @redis = opt[:connection] 
      @serializer = opt[:serializer] || Marshal
    end

  end
end
