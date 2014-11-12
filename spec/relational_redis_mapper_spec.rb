require 'spec_helper'
require 'relational_redis_mapper'

module HashInit
  def initialize(opt={})
    opt.each { |k,v| send "#{k}=", v }
  end
end

class Auction
  include RelationalRedisMapper
  include HashInit
  attr_accessor :name, :time, :product
  validate_uniqueness_of :name
  query_attr :name, :time
  has_many_ordered bids: :price
  #has_many :people

  def timestamp
    time.to_i
  end
end

class Product
  include HashInit
  include RelationalRedisMapper
  attr_accessor :name, :price, :available
  validate_uniqueness_of :name
  query_attr :name, :price
  has_many_ordered auctions: :timestamp
end


$redis = RelationalRedisMapper::Redis.set(connection: ::Redis.new)

describe Product do

  let(:macbook) { Product.new(name: 'MacBook', price: 1999.99) }
  let(:iphone) { Product.new(name: 'Iphone', price: 1999.99) }
  let(:auction)  { Auction.new(name: 'Second Macbook auction', time: Time.new(2007,11,10))  }

  before do 
    $redis.flushall; macbook.save; iphone.save

    @macbook = Product.new(name: 'MacBook_2', price: 1999.99) 

    5.times do |x|
      time = Time.new(2000 + x,1,1)
      auction = instance_variable_set "@auction_#{x}", Auction.new(name: "Macbook #{x}", time: time)  
      auction.save
      @macbook.auctions << auction
    end

  end

  context "regular queries" do
    it 'should return first by name or price' do
      by_name = Product.find_by_name macbook.name
      by_price = Product.find_by_name iphone.name
      expect(by_name.name).to eq 'MacBook'
      expect(by_price.name).to eq 'Iphone'
    end

    it 'should return nil when no match is found'do
      by_price = Product.find_by_price 123
      expect(by_price).to be_nil
    end

    it 'should return all results by price' do
      all_price = Product.where :price, 1999.99
      expect(all_price).to include macbook, iphone
    end

    it 'should return emtpy array when no match is found' do
      by_price   = Product.where :price, 123
      expect(by_price).to be_empty
    end

    it 'should get all products' do
      expect(Product.all).to include iphone, macbook
    end
  end

  context 'relational queries' do

    it 'should return multiple associations' do
      auctions = @macbook.auctions.all
      expect(auctions).to include @auction_1, @auction_2, @auction_3, @auction_4
      expect(auctions).not_to include auction
      expect(iphone.auctions.all).to be_empty
    end

    it 'should return earliest auction associated to product' do
      expect(@macbook.auctions.first).to eq @auction_0
    end

    it 'should return latest auction associated to product' do
      expect(@macbook.auctions.last).to eq @auction_4
    end

    it 'should query assocation' do
      query_by_assoc = @macbook.auctions.where(:name, @auction_0.name)
      other          = iphone.auctions.where(:name, @auction_0.name)
      expect(query_by_assoc).to eq [@auction_0]
      expect(other).to be_empty
    end
  end

  context 'persistance' do 

    context 'delete' do
      before { macbook.delete }

      it 'should delete an object' do
        persisted = $redis.hget macbook.class_key, macbook.id
        expect(persisted).to be_nil
      end

      it 'should remove the indexes' do 
        existing_indices = macbook.uniqueness_attr.select do |attr| 
          $redis.find_id macbook.key_gen.query_key(attr, macbook.send(attr))
        end
        expect(existing_indices).to be_empty
      end

    end

    it 'should not save same item twice' do
      expect{ macbook.save }.to raise_exception
    end

    it 'should update item' do 
      old_name = macbook.name; new_name = 'Macbook Pro'
      macbook.name = new_name; macbook.save
      expect(Product.find_by_name(old_name)).to be_nil
      expect(Product.find_by_name(new_name).name).to eq 'Macbook Pro'
    end

    it 'should not save two items with same name' do
      b = macbook.dup
      expect{ b.save }.to raise_exception
    end

  end
end

