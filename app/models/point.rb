class Point
  attr_accessor :longitude, :latitude

  def initialize(params = {})
    if params[:coordinates]
      @longitude, @latitude = params[:coordinates]
    else
      @latitude = params[:lat]
      @longitude = params[:lng]
    end
  end

  def to_hash
    { type: 'Point', coordinates: [longitude, latitude] }
  end
end
