class Skill
  attr_accessor :id, :percentage, :cp, :level, :name
  def initialize(id, name, cp, level, percentage)
    @id = id
    @name = name
    @cp = cp
    @level = level
    @percentage = percentage
  end
end