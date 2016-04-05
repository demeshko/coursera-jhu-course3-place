class AddressComponent
  attr_reader :long_name, :short_name, :types

  def initialize(input_hash = HashWithIndifferentAccess.new)
    @short_name = input_hash[:short_name]
    @long_name = input_hash[:long_name]
    @types = input_hash[:types]
  end
end
