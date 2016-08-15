DAMAGE_DECORATORS = [
  ['miss', 'misses', 'clumsy', ''],
  ['bruise', 'bruises', 'clumsy', ''],
  ['scrape', 'scrapes', 'wobbly', ''],
  ['scratch', 'scratches', 'wobbly', ''],
  ['lightly wound', 'lightly wounds', 'amateur', ''],
  ['injure', 'injures', 'amateur', ''],
  ['harm', 'harms', 'competent', ', creating a bruise'],
  ['thrash', 'thrashes', 'competent', ', leaving marks'],
  ['decimate', 'decimates', 'cunning', ', the wound bleeds'],
  ['devastate', 'devastates', 'cunning', ', hitting organs'],
  ['mutilate', 'mutilates', 'calculated', ', shredding flesh'],
  ['cripple', 'cripples', 'calculated', ', leaving GAPING holes'],
  ['DISEMBOWEL', 'DISEMBOWELS', 'calm', ', guts spill out'],
  ['DISMEMBER', 'DISMEMBERS', 'calm', ', blood sprays forth'],
  ['ANNIHILATE!', 'ANNIHILATES!', 'furious', ', revealing bones'],
  ['OBLITERATE!', 'OBLITERATES!', 'furious', 'furious', ', rending organs'],
  ['DESTROY!!', 'DESTROYS!!', 'frenzied', 'frenzied', ', shattering bones'],
  ['MASSACRE!!', 'MASSACRES!!', 'barbaric', 'barbaric', ', gore splatters everywhere'],
  ['!DECAPITATE!', '!DECAPITATES!', 'deadly', 'deadly', ', scrambling some brains'],
  ['@r!!SHATTER!!@x', '@r!!SHATTERS!!@x', 'legendary', 'legendary', ' into tiny pieces'],
  ['do @rUNSPEAKABLE@x things to', 'does @rUNSPEAKABLE@x things to', 'ultimate', '!'],
]

class Mobile
  attr_reader :id, :room_id, :user_id, :start, :character_id
  attr_accessor :experience, :level, :base,:commands, :basic_commands, :class_commands, :combat, :combat_buffer, :behaviors, :affects, :inventory, :stats, :equipment, :skills, :stats, :name, :short, :long, :keywords, :description

  def initialize(id, room_id, game, user_id = nil)
    @id = id
    @user_id = user_id
    @lag = 0
    @room_id = room_id
    @game = game
    @combat = nil
    
    @basic_commands = []
    @class_commands = []
    #@commands = [] #???
    @combat_buffer = ""
    @command_queue = []
    
    @behaviors = {}
    @inventory = []
    @equipment = {}
    @skills = {}
  end

  def addCommands
    extend BasicCommands
    extend ThiefCommands
  end

  def commands
    @basic_commands | @class_commands
  end

  def setCharacterInfo(name, short, long, keywords, description, level, experience, stats)
    @name = name
    @short = short
    @long = long
    @keywords = keywords ? keywords.split(',') : [@name]
    @description = description
    @level = level
    @experience = experience
    @stats = stats
    @base = stats.clone
  end

  def prompt
    "<p class='prompt'>#{stat('hitpoints').to_i}/#{base('hitpoints')} hp #{stat('manapoints').to_i}/#{base('hitpoints')} mp</p>"
  end

  def equip(slot, item)
    puts "#{slot}, #{item}"
    if item
      puts "Equipping! #{item.name}"
    end
    if !@equipment[slot].nil?
      @inventory.push(unequip(slot))
    end
    @equipment[slot] = item
  end

  def unequip(slot)
    if @equipment[slot]
      item = @equipment[slot].clone
      @equipment.delete(slot)
      item
    end
  end

  def addItem(item)
    @inventory.push(item)
  end

  def removeItem(name)
    item = @inventory.select { |item| item.match(/\A#{name}.*/) }.first    
    @inventory.delete(item)
    item
  end

  def addBehavior(behavior)
    b = behavior.new(self)
    @behaviors[behavior.to_s] = b
    b.onStart
  end

  def hasBehavior(keys)
    keys = Array(keys)
    keys.each do |key|
      if @behaviors.key? key
        return true
      end
    end
    return false
  end

  def removeBehavior(key)
    if @behaviors.key? key
      @behaviors[key].onEnd
      @behaviors.delete(key)
    end
  end

  def update(dt)
    if @lag > 0
      @lag -= dt
    elsif (c = @command_queue.pop)
      handle(c['message'])
    end
    @behaviors.each{ |k, b| b.update(dt) }

    if stat("hitpoints") <= 0
      die
    end 
    # that's the command part, below we have the combat, which behaves by the same rules for everyone
  end

  def die
    if @combat
      buffer = ""
      if user_id
        @game.emit do |user|
          "#{@name} suffers defeat at the hands of #{@combat.name}!!"
        end
      else
        #looting from npcs only, at the moment
        @inventory.each do |item|
          #item.render
          buffer += "You get #{item.name} from the corpse of #{render(@combat)}.<br>"
          @combat.addItem item
        end
      end

      buffer += "#{@name} is DEAD!!<br>"
      buffer = @combat.do_xp(self, buffer)
      @combat.emit buffer
      end_combat
    end
    if @user_id
      @stats = @base.clone
      @behaviors = {}
      emit "You have been KILLED!"
      addBehavior(Nervous)
      addBehavior(Rest)
    else
      @game.removeMobile(self)
    end
  end

  def do_xp(mobile, buffer = nil)
    xp = [[-5, (mobile.level - @level)].max, 5].min * 50 + 250
    @experience += xp
    if buffer
      buffer += "You get #{xp} experience points."
    else
      emit "You get #{xp} experience points."
    end
    if @level < (@experience.to_f / xp_per_level).ceil 
      @level += 1
      if buffer
        buffer += "You have gained a level!  You are now level #{@level}."
      else
        emit "You have gained a level!  You are now level #{@level}."
      end
    end
    buffer
  end

  def xp_per_level
    @skills.map{ |k, v| v.cp}.reduce{ |s1, s2| s1 + s2 } * 100
  end

  def check_combat(mobile)
    if is mobile
      emit "Suicide is a mortal sin."
      return false
    elsif mobile.hasBehavior("Nervous")
      emit "Give them a chance to breath."
      return false
    elsif hasBehavior("Rest")
      emit "Try standing up first."
      return false
    elsif hasBehavior("Nervous")
      emit "You are too nervous to start anything like that."
      return false
    elsif mobile && mobile == @combat
      return true
    elsif @combat
      emit "You are already fighting someone!"
      return false
    else
      return true
    end
  end

  def start_combat(mobile, check=true)
    if !check_combat(mobile) && check
    else
      @combat = mobile
      mobile.combat = self
      removeBehavior("Hide")
      return true
    end
  end

  def end_combat
    @combat.combat = nil
    @combat = nil
  end

  def skill(name)
    yield rand(100) <= @skills[name.downcase].percentage
  end

  def base(key)
    @base[key].to_i
  end

  def do_round
    if @combat
      do_hit(noun)
      10.times do |i|
        return unless @combat
        n = rand(10) + i * 10
        if n < stat("attackspeed")
          do_hit(noun)
        end
      end

      @behaviors.each do |k, b|
        return unless @combat
        b.onCombat
      end
    end
  end

  def emit(msg)
    @game.emit { |user| msg if is user }
  end

  def get_percentage
    100 * stat("hitpoints") / base("hitpoints")
  end

  def render_condition(from)
    percentage = get_percentage

    if percentage == 100
      condition = "#{render(from)} is in excellent condition."
    elsif percentage >= 80
      condition =  "#{render(from)} has some small wounds and bruises."
    elsif percentage >= 60
      condition =  "#{render(from)} has quite a few wounds."
    elsif percentage >= 40
      condition =  "#{render(from)} has some big nasty wounds and scratches."
    elsif percentage >= 20
      condition =  "#{render(from)} is pretty hurt."
    elsif percentage > 0
      condition =  "#{render(from)} is in awful condition."
    else
      condition =  "BUG: #{render(from)} is mortally wounded and should be dead."
    end
    condition
  end

  def do_hit(noun, buffered=true, modifiers={})
    if rand(10) < stat('hitroll') + modifiers[:hitroll].to_i
      damage = @combat.do_damage(rand(stat('damage')) + stat('damage') + modifiers[:damage].to_i)
    else
      damage = 0
    end
    for_them, for_you, for_room = decorate_combat(damage)
    if buffered
      @combat.combat_buffer += for_them
      @combat_buffer += for_you
    else
      @combat.emit for_them
      emit for_you
    end
  end

  def decorate_combat(damage)
    puts "damage: #{damage}"
    min = 0
    max = 100
    i = (DAMAGE_DECORATORS.length * (damage - min) / (max - min)).round
    return [
      "#{render(@combat)}'s #{DAMAGE_DECORATORS[i][2]} #{noun} #{DAMAGE_DECORATORS[i][1]} you#{DAMAGE_DECORATORS[i][3].length > 0 ? DAMAGE_DECORATORS[i][3] : '.'}<br>",
      "Your #{DAMAGE_DECORATORS[i][2]} #{noun} #{DAMAGE_DECORATORS[i][1]} #{@combat.render(self)}#{DAMAGE_DECORATORS[i][3].length > 0 ? DAMAGE_DECORATORS[i][3] : '.'}<br>",
      ""
    ]
  end

  def noun
    if @equipment["weapon"] && @equipment["weapon"].noun
      puts "got a noun"
      @equipment["weapon"].noun
    else
      "entangle"
    end
  end

  def do_damage(n)
    d = (n - rand(stat('damagereduction')))
    @stats["hitpoints"] -= d
    return d
  end

  def command(cmd)
    @command_queue.push(cmd)
  end

  def is(user)
    if @user_id
      @user_id == user.user_id
    else
      @id == user.id
    end
  end

  def stat(key)
    if @stats[key]
      @stats[key] + @behaviors.map{ |k, b| b.stat(key) }.reduce(:+).to_i + @equipment.map { |_, i| i ? i.stat(key) : 0 }.reduce(:+).to_i # fix me: should use equipment, currently using inventory
    else
      0
    end
  end

  def room
    @game.rooms[@room_id]
  end

  def character
    puts "DEPRECATES"
    self
  end

  def target_mobile(args)
    targets = @game.mobiles.select do |mobile| 
      mobile.room_id == @room_id && mobile.render(self, :keywords).match(/\b#{args[0]}/i) && can_target(mobile)
    end
    target = targets.first
  end

  def target_item(args, list)
    list.select { |i| i && i.name.downcase.match(/\A#{args[0]}/) && can_target(i) }.first
  end

  def can_target(mobile)
    # if blind, cannot target at all
    if hasBehavior(["Blind", "Dirtkick", "Smokebomb"])
      return false
    elsif mobile.hasBehavior(["Hide"])
      return false
    elsif mobile.hasBehavior(["Invisible"]) && !hasBehavior(["DetectInvisible"])
      return false
    end
    return true
  end

  def target_exit(args)
    exit = room.exits.select { |direction, room_id| direction.downcase.match(/\A#{args[0]}/)}.first
    if exit
      puts exit
      return [exit[0], @game.rooms[exit[1]]]
    else
      return false
    end
  end

  # the render function gives output to be sent to a player.  this is where we can handle things that affect rendering, like blind
  def render(from, format = :short)
    # if hidden, shouldn't even try to hide?
    if format == :keywords
      return @keywords.join(" ")
    end

    if is from
      return "You"
    end

    if hasBehavior("Hide") || from.hasBehavior(["Blind", "Dirtkick", "Smokebomb"])
      return "Someone"
    end

    case format
    when :short
      @name
    when :long
      %(
        <h4>#{@name}</h4>
        <p>#{@long}</p>
        #{@equipment.map{ |slot, item| slot + ": " + item.name }.join("<br>")}
      )
    else
      @name
    end
  end

  def handle(cmd)
    # ideally this with inherit from modules, depending on class, etc.
    if cmd.nil?
      return
    end

    args = cmd.split " "
    cmd = args.shift
    cmd = commands.select{ |command| command.match(/\A#{cmd}.*\z/) }.first
    if cmd.nil?
      emit "Huh?"
    elsif @skills[cmd] && @level < @skills[cmd].level
      emit "You are not high level enough to use that skill."
    else
      @lag = send("cmd_#{cmd}", args).to_i
    end

  end
end