class Room
  attr_reader :name, :description, :exits

  def initialize(id, name, description, exits, game)
    @id = id
    @name = name
    @description = description
    @exits = exits
    @game = game
  end

  def render(from, format = :short)
    %(
      <div class='room'>
      <h4>#{name}</h4>
      <p>#{description}</p>
      <ul class='list-inline'><li>[#{exits.map{|k,v| k}.join("]</li><li>[")}]</li></ul>
      #{@game.mobiles.select{ |mobile| mobile.room_id == @id && !from.is(mobile) }.map{ |mobile| "<p>" + mobile.render(from) + " is here</p>"}.join}
      </div>
    )
  end
end