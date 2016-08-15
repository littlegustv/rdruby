class Character
  attr_reader :name, :description, :stats
  def initialize(name, description, stats)
    @name = name
    @description = description
    @stats = stats
  end
end