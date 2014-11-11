require "relational_redis_mapper/version"
require 'redis'
require 'json'
require 'pry'
require 'active_support/inflector'
require 'relational_redis_mapper/redis'
require 'relational_redis_mapper/relation'

$redis = Redis.new

module RelationalRedisMapper

  extend Forwardable
  attr_accessor :persisted, :id

  def self.included(base)
    base.extend ClassMethods
  end

  def_delegators :klass, :class_key, :search_key, :query_keys, :uniqueness_attr, :find, :has_many_relations

  def klass
    self.class
  end

  def redis
    @redis ||= Redis.new
  end

  #relations
  #def get_has_many(relation)
  #ids = $redis.lrange relation_key(relation), 0, -1
  #const_get(relation.to_s.capitalize).find_all_by_ids ids
  #end

  def to_hash
    instance_variables.each_with_object({}) do |var, hash| 
      hash[var.to_s.delete("@").to_sym] = instance_variable_get(var) 
    end
  end

  def uuid
    @uuid ||= SecureRandom.uuid
  end

  def save_object
    self.id = uuid
    $redis.hset class_key, uuid, self.to_hash.to_json
  end

  def delete_object
    $redis.hdel class_key, id
  end

  #indices
  def save_relational_indices(relation)
    #$redis.lpush relation_key(relation), relation.id
    @ordered_relations.each 
  end

  def save_indices
    query_keys.each { |attr| $redis.lpush search_key(attr, send(attr)), uuid }
    uniqueness_attr.each { |attr| $redis.set uniq_key(attr, send(attr)), uuid }
  end

  def remove_indices
    query_keys.each { |attr| $redis.lrem search_key(attr, send(attr)),1, uuid }
    uniqueness_attr.each { |attr| $redis.del uniq_key(attr, send(attr)) }
  end

  def relation_key(relation)
    "has_many:#{class_key}:#{relation.class_key}"
  end

  def uniq_key(attr, val)
    "unique:#{class_key}:#{attr}:#{val}"
  end

  def passes_unique_validator?
    uniqueness_attr.none? { |attr| $redis.get uniq_key(attr, send(attr)) }
  end

  class ValidationError; end

  def validate 
    passes_unique_validator? ? true : raise(ValidationError)
  end

  def save 
    changed.delete if changed
    if validate
      save_object
      save_indices
      return self
    end
    nil
  end

  def delete
    remove_indices; delete_object
  end

  def changed
    if (other = find(id)) && (other != self)
      other
    end
  end

  def persisted?
    self.id
  end

  def ==(other)
    #self.to_hash == other.to_hash
    self.id == other.id
  end

  def dup
    dup = super; dup.id = nil; dup
  end

  module ClassMethods

    class ValidationError < Struct.new(:attribute, :message);end


    #attr_readers that default to empty array
    [:ordered_relations, :query_keys, :uniqueness_attr, :has_many_relations].each do |reader|
      define_method reader do
        instance_variable_get "@#{reader}" || [] 
      end
    end

    def query_attr(*keys)
      @query_keys = keys
      keys.each do |key|

        define_singleton_method "find_by_#{key}" do |query| 
          id = $redis.lindex(search_key(key, query), 0)
          find id
        end

      end
    end

    def find(id)
      hash_init $redis.hget(class_key, id) rescue nil
    end

    def find_all_by_ids(ids)
      $redis.hmget(class_key, ids).map do |json| 
        hash_init json
      end rescue nil
    end

    def where(attr, val)
      find_all_by_ids where_ids(attr, val)
    end

    def where_ids(attr, val)
      $redis.lrange search_key(attr, val), 0, -1
    end

    def search_key(attr_nm, attr_val)
      "index:#{class_key}:#{attr_nm}:#{attr_val}"
    end

    def hash_init(json_hash)
      JSON.parse(json_hash).each_with_object(new) do |(k,v), instance|
        instance.instance_variable_set "@#{k}", v
      end
    end

    def has_many_ordered(opt)
      @ordered_relations = opt

      opt.each do |relation_collection, order_by|

        define_method relation_collection do 
          unless instance_variable_defined? "@#{relation_collection}"
            instance_variable_set "@#{relation_collection}", Relation.new(self, relation_collection)
          end
          instance_variable_get "@#{relation_collection}"
        end

        #define_method "add_#{relation}" do |relation|
          #key = relation_key(relation)
          #relation.save
          #score = relation.send(order_by)
          #$redis.zadd(key, score, relation.id)
        #end

      end
    end

    def has_many(*others)
      @has_many_relations = others

      others.each do |relation|
        define_method relation do
          Relation.new(self, relation)
        end

      end
    end

    def all
      $redis.hgetall(class_key).values.map { |x| hash_init x }
    end

    def class_key
      self.to_s.gsub(/::/, '_').downcase
    end

    def validate_uniqueness_of(*args)
      @uniqueness_attr = args
    end


  end

end
