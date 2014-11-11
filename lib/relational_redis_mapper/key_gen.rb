module RelationalRedisMapper
  class KeyGen

    attr_reader :class_key

    def initialize(klass)
      @class_key = klass.to_s.deconstantize
    end

    def query_key(attr_nm, attr_val)
      "index:" << class_attr_val_key(attr_nm, attr_val)
    end

    #used for uniqueness validator
    def uniqueness_key(attr, attr_val)
      "uniqueness:" << class_attr_val_key(attr, attr_val)
    end

    def class_attr_val_key(attr, attr_val)
      "#{class_key}:#{attr}:#{attr_val}"
    end

    def uniq_id
      SecureRandom.uuid
    end

  end
end
