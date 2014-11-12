require "relational_redis_mapper/version"
require 'redis'
require 'active_support/inflector'
require 'relational_redis_mapper/redis'
require 'relational_redis_mapper/relation'
require 'relational_redis_mapper/key_gen'
require 'relational_redis_mapper/utility_methods'

module RelationalRedisMapper
  include UtilityMethods
  extend Forwardable

  attr_accessor :persisted, :id

  def self.included(base)
    base.extend ClassMethods
  end

  def_delegators :klass, :class_key, :query_keys, :uniqueness_attr, :key_gen, :redis

  def id
    @id ||= key_gen.uniq_id
  end

  class ValidationError; end

  def validate
    uniqueness_attr.none? do |attr| 
      redis.get_uniq_index key_gen.uniqueness_key(attr, send(attr)) 
    end || raise(ValidationError)
  end

  def save 
    persisted_version.delete if changed?
    if validate
      save_object; modify_indices(:create)
      return self
    end
    nil
  end

  def delete
    modify_indices; delete_object
  end

  def changed?
    persisted_version && persisted_version != self
  end

  def persisted_version
    klass.find(id) 
  end
  
  private

  def save_object
    redis.save_object class_key, id, self
  end

  def delete_object
    redis.delete_object class_key, id
  end
 
  def modify_indices(create=false)
    indices_each(create) do |redis_key, redis_method|
      redis.send redis_method, redis_key, id
    end
  end

  def indices_each create, &block 
    if create
      redis_query_method, redis_unique_method = :add_query_index, :add_uniq_index
    else
      redis_query_method, redis_unique_method = :rm_search_index, :rm_uniq_index 
    end
    query_keys.each      { |attr| block.call key_gen.query_key(attr, send(attr)), redis_query_method }
    uniqueness_attr.each { |attr| block.call key_gen.uniqueness_key(attr, send(attr)), redis_unique_method }
  end


  module ClassMethods

    #attr_readers that default to empty array
    [:query_keys, :uniqueness_attr].each do |reader|
      define_method reader do
        instance_variable_get "@#{reader}" || [] 
      end
    end

    def validate_uniqueness_of(*args)
      @uniqueness_attr = args
    end

    def query_attr(*keys)
      @query_keys = keys
      keys.each do |key|

        define_singleton_method "find_by_#{key}" do |query| 
          find redis.find_id(key_gen.query_key(key, query))
        end

      end
    end

    def has_many_ordered(opt)
      opt.each do |relation_collection, order_by|

        define_method relation_collection do 
          instance_variable_set(
            "@#{relation_collection}", 
            instance_variable_get("@#{relation_collection}") ||
            Relation.new(self, relation_collection, order_by) 
          )
        end

      end
    end
    alias_method :has_many, :has_many_ordered


    def find(id)
      redis.find_object(class_key, id) 
    end

    def find_all_by_ids(ids)
      redis.find_objects(class_key, ids)
    end

    def where(attr, attr_val)
      find_all_by_ids get_all_ids(attr, attr_val) 
    end

    def get_all_ids(attr, val)
      redis.find_ids key_gen.query_key(attr, val)
    end

    def all
      redis.all_objects(class_key)
    end

    def class_key
      key_gen.class_key
    end

    private

    def redis
      Redis.get(connection: ::Redis.new)
    end

    def key_gen
      @key_gen ||= KeyGen.new(self)
    end

  end

end
