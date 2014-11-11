module RelationalRedisMapper
  module UtilityMethods

    def klass
      self.class
    end

    def ==(other)
      self.to_hash == other.to_hash
    end

    def to_hash
      instance_variables.each_with_object({}) do |var, hash|
        hash[var] = instance_variable_get(var)
      end
    end

    def dup
      dup = super; dup.id = nil; dup
    end

  end
end
