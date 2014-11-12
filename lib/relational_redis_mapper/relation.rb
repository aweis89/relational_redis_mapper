module RelationalRedisMapper
  class Relation
    
    extend Forwardable
    include Enumerable

    attr_reader :subject, :relation_sym, :order_by_method
    def_delegators :relation_klass, :find_all_by_ids, :get_all_ids, :find

    def initialize(subject, relation_sym, order_by_method=nil)
      @subject         = subject
      @relation_sym    = relation_sym
      @order_by_method = order_by_method
    end

   def << relation 
      $redis.zadd(relation_key, score(relation), relation.id)
      all
    end

    def all
      find_all_by_ids all_relation_ids
    end

    def where(attr, val)
      intersection_ids = all_relation_ids & get_all_ids(attr, val)
      find_all_by_ids intersection_ids
    end
      
    def first
      find all_relation_ids(0,0)
    end

    def last
      find all_relation_ids(-1,-1)
    end

    private
    def relation_key
      "#{subject.class_key}:#{relation_klass.class_key}:#{subject.id}"
    end
    def all_relation_ids(start=0, stop=-1)
      $redis.zrange(relation_key, start, stop)
    end
    def score(object)
      order_by_method ? object.send(order_by_method) : 0
    end
    def relation_klass
      relation_sym.to_s.classify.constantize
    end

  end
end
