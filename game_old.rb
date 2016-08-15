class GameRoom
  attr_accessor :id, :name, :description, :exits, :mobiles

  def initialize(id, name, description, exits)
    @id = id
    @name = name
    @description = description
    @exits = exits
    @mobiles = []
  end

  def characters
    self.mobiles.map { |mobile| mobile.character }
  end

  def display
    display = %(
      <h1>#{name}</h1>
      <p>#{description}</p>
      <ul class="list-inline">
        <li class="h4">Exits</li>
        #{exits.map { |exit| '<li>' + exit[0] + '</li>'}.join}
      </ul>
      <ul class="list-inline">
        #{characters.map { |c| '<li>' + c.name + ' is here.</li>'}.join}
      </ul>
    )
=begin
<ul style="list-style: none;">
  #{room_items.map { |c| '<li>' + c.item.name + '</li>'}.join}
</ul>
=end
  end
end

class GameMobile
  attr_accessor :user_id, :character, :room

  def initialize(user_id, character, room)
    @user_id = user_id
    @character = character
    @room = room
    @room.mobiles.push(self)
  end

  def move(direction)
    if self.room.exits.key? direction
      self.room.mobiles.delete(self)
      self.room = self.room.exits[direction]
      self.room.mobiles.push(self)
      return "You move #{direction}."
    else
      return "You can't go that way."
    end
  end

  def speak(msg)
    if user_id
      ActionCable.server.broadcast "clients_#{user_id}", message: msg
    end
  end

end

class GameCharacter
  attr_accessor :id, :name, :description

  def initialize(id, name, description)
    @id = id
    @name = name
    @description = description
  end
end

class Game
  def initialize
    @commands = []
    @players = {}  #user_id => mobile
    loadcharacters
    loadrooms
    #@rooms = Room.all
  end

  def loadrooms
    @rooms = {}
    rooms = Room.all
    rooms.each do |room|
      r = GameRoom.new(room.id, room.name, room.description, Hash[room.exits.map { |exit| [exit.direction, exit.destination_id] }] )
      @rooms[room.id] = r
      
      room.mobiles.each do |mobile|
        r.mobiles.push(GameMobile.new(nil, @characters[mobile.character_id], r))
      end

    end

    @rooms.each do |_, room|
      room.exits.each do |direction, exit|
        room.exits[direction] = @rooms[exit]
      end
    end
  end

  def loadcharacters
    @characters = {}
    Character.all.each do |character|
      @characters[character.id] = GameCharacter.new(character.id, character.name, character.description)
    end
  end

  def speak(channel, msg)
    ActionCable.server.broadcast channel, message: msg, user: ""
  end

  def run
    loop {
      if (cmd = @commands.pop)
        handleCommand(cmd)
      end
      sleep 1.0 / 60
    }
  end

  def handleCommand(c)
    puts "Handling command: #{c.inspect}"
    channel = "clients_#{c['user']}"
    cmd = c["message"]
    #u = players = @players.select { |player| player.id == c['user'] }.first.try
    #u = u.count > 0 ? u.first : nil
    if u = @players[c['user']]
    else
      user = User.find(c['user'])
      if @players[c['user']] 
        u = player[c['user']]
      elsif user.mobile
        @players[user.id] = GameMobile.new(user.id, @characters[user.mobile.character_id], @rooms[user.mobile.room_id])
        u = @players[user.id]
      else
        puts "ERROR: You should have a character,yes you should."
        speak channel, message: "Error: who are you?"
      end
    end

    case cmd
    when u.nil?
      speak(channel, 'WHO ARE YOU?')
    when "look"
      u.speak u.room.display
    when *["north", "south", "east", "west", "up", "down"]
      move = u.move(cmd.humanize)
      @players.select{ |_, p| p != u && p.room == u.room }.each{ |_, p| p.speak "#{u.character.name} leaves #{cmd}."} if move == "You move #{cmd.humanize}."
      speak(channel, move)
      @players.select{ |_, p| p != u && p.room == u.room }.each{ |_, p| p.speak "#{u.character.name} has arrived."} if move == "You move #{cmd.humanize}."
      @commands.push({"message" => "look", "user" => u.user_id }) if move == "You move #{cmd.humanize}."
    #when "quit"
      #@players.delete(u.id)
      # need some way of saving the mobile without it still showing up in game... just an 'active' field? 
      # for now just delete it, you will just 'restart' in beginning room eahc login
      #u.mobile.destroy
    when /say\s(.+)/
      string = cmd.match(/say\s(.+)/)[1]
      u.speak "You say '#{string}'"
      @players.each { |_, p| p.speak "#{u.character.name} says '#{string}'" if p != u && p.room == u.room }
    else
      u.speak("Huh?")
    end

  end

  def command(cmd)
    @commands.push(cmd)
  end
end