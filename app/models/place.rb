# require 'json'
# require 'mongo'
class Place
  include ActiveModel::Model
  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(params = HashWithIndifferentAccess.new)
    @id = params[:_id].nil? ? params[:_id] : params[:_id].to_s
    @formatted_address = params[:formatted_address] || nil
    @location = Point.new(params[:geometry][:geolocation]) || nil
    if params[:address_components]
      @address_components = params[:address_components].map do |component|
        AddressComponent.new(component)
      end
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client['places']
  end

  def self.load_all(file_path)
    file = File.read(file_path)
    collection.insert_many(JSON.parse(file))
  end

  def self.find_by_short_name(short_name)
    collection.find(:'address_components.short_name' => short_name)
  end

  def self.to_places(view)
    view.nil? ? nil : view.inject([]) { |a, e| a << Place.new(e) }
  end

  def self.find(id)
    obj = collection.find(_id: BSON::ObjectId.from_string(id)).first
    obj.nil? ? nil : Place.new(obj)
  end

  def self.all(offset = 0, limit = nil)
    result = collection.find.skip(offset)
    result = result.limit(limit) if limit
    result.map { |e| Place.new(e) }
  end

  def persisted?
    !@id.nil?
  end

  def destroy
    self.class.collection.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end

  def self.get_address_components(sort = {}, offset = 0, limit = nil)
    query = [{ :$unwind => '$address_components' },
             { :$project => {
                              address_components: 1,
                              formatted_address: 1,
                              :'geometry.geolocation' => 1 } }
    ]
    query << { :$sort => sort } unless sort.size.zero?
    query << { :$skip => offset } unless offset.zero?
    query << { :$limit => limit } unless limit.nil?
    collection.find.aggregate(query)
  end

  def self.get_country_names
    query = [ { :$unwind => '$address_components' },
              { :$project => { :'address_components.long_name' => 1,
                               :'address_components.types' => 1, }},
              { :$match => { :'address_components.types' => "country" }},
              { :$group => { :_id => '$address_components.long_name'}}
    ]
    collection.find.aggregate(query).to_a.map {|h| h[:_id]}
  end

  def self.find_ids_by_country_code(country_code)
    query = [
      { :$match => { :'address_components.short_name' => country_code } },
      { :$project => { _id: 1 } }
    ]
    collection.find.aggregate(query).map {|doc| doc[:_id].to_s}
  end

  def self.create_indexes
    collection.indexes.create_one(:'geometry.geolocation' => Mongo::Index::GEO2DSPHERE)
  end

  def self.remove_indexes
    collection.indexes.drop_one('geometry.geolocation_2dsphere')
  end

  def self.near(point, max_meters = 0)
    query = { :$near => point.to_hash }
    query[:$maxDistance] = max_meters unless max_meters.zero?
    collection.find(:'geometry.geolocation' => query)
  end

  def near(meters = 0)
    docs = self.class.near(@location, meters)
    self.class.to_places(docs)
  end

  def photos(offset = 0, limit = nil)
    photos = Photo.find_photos_for_place(@id)
    photos = photos.skip(offset) unless offset.zero?
    photos = photos.limit(limit) unless limit.nil?
    photos.map { |p| Photo.find(p[:_id].to_s) }
  end
end
