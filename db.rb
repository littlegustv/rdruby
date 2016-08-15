SQLITEPATH = ENV["PWD"].gsub("game", "db") + "/development.sqlite3"

module SQLITE

  require 'sqlite3'

  def initDB
    begin
      @db = SQLite3::Database.new SQLITEPATH
    rescue SQLite3::CantOpenException
      puts "************************************** ALERT! ************************************"
      puts "Cannot open Database File.  Make sure you have set the correct location in db.rb"
      puts "Enter the complete path to the SQLITE db file, found in your db/ directory of your"
      puts "rails project."
      puts "**********************************************************************************"
    end
  end

  def loadRooms
    @rooms = {}
    rows = @db.execute "select id, name, description from rooms"
    rows.each do |row|
      id = row[0]
      
      exits = @db.execute "select direction, destination_id from exits where room_id = ?", id
      room_exits = {}
      exits.each do |exit|
        room_exits[exit[0]] = exit[1]
      end      

      @rooms[id] = Room.new(id, row[1], row[2], room_exits, self)
    end
  end

  def loadMobiles
    rows = @db.execute "select id, room_id, character_id from mobiles where user_id is null"
    rows.each do |row|
      loadMobile(row, self)
    end
  end

  def loadMobile(mobile_info, game, user_id = nil)
    if mobile_info.nil?
      return
    end
    u = Mobile.new(mobile_info[0], mobile_info[1], game, user_id)
    if @mobiles.select { |m| m.id == mobile_info[0] }.count <= 0
      loadInventory(u, mobile_info[2])
      loadEquipment(u, mobile_info[2])
      loadSkills(u, mobile_info[2])
      loadCharacterInfo(u, mobile_info[2])
      u.addCommands
      @mobiles.push(u)
      if user_id
        @users.push(u)
      end
    end
    u
  end

  def loadInventory(m, cid)
    items = @db.execute "select item_id from inventory_items where character_id = ?", cid
    items.each do |item|
      #puts "here", item[0], @items[item[0]]
      if @items.key?(item[0])
        m.addItem(@items[item[0]].clone)
      end
    end
  end

  def loadEquipment(m, cid)
    equipment = @db.execute "select weapon_id, head_id from equipment where character_id = ?", cid
    if equipment && equipment.count > 0
      equipment = equipment[0]
    else
      return
    end
    m.equip("weapon", @items[equipment[0]])
    m.equip("head", @items[equipment[1]])
  end
=begin
  def loadCharacters
    @characters = {}
    rows = @db.execute "select id, name, description, stat_id from characters"
    rows.each do |row|
      stat = @db.execute "select attackspeed, damagereduction, hitpoints, manapoints, damage from stats where id = ?", row[3]
      stat = Hash[['attackspeed', 'damagereduction', 'hitpoints', 'manapoints', 'damage'].zip(stat[0])]
      @characters[row[0]] = Character.new(row[1], row[2], stat)
    end
  end
=end
  def loadCharacterInfo(mobile, id)
    new_row = @db.execute("select id, name, short, long, keywords, description, level, experience, stat_id from characters where id = ?", id).first
    if new_row
      stat = loadStat(new_row[8])
      mobile.setCharacterInfo(new_row[1], new_row[2], new_row[3], new_row[4], new_row[5], new_row[6], new_row[7], stat)
    end
  end
  
  def loadItems
    @items = {}
    rows = @db.execute "select id, name, description, stat_id, slot, noun, level from items"
    rows.each do |row|
      stat = loadStat(row[3])
      @items[row[0]] = Item.new(row[1], row[2], stat, row[4], row[5], row[6])
    end
  end

  def loadStat(id)    
    stat = @db.execute "select attackspeed, damagereduction, hitpoints, manapoints, damage, hitroll from stats where id = ?", id
    stat = Hash[['attackspeed', 'damagereduction', 'hitpoints', 'manapoints', 'damage', 'hitroll'].zip(stat[0])]
  end

  def loadSkills(mobile, cid)
    character_skills = @db.execute "select skill_id, percentage from character_skills where character_id = ?", cid
    character_skills.each do |cs|
      skill_info = @db.execute("select name, cp, level from skills where id = ?", cs[0]).first
      if skill_info
        mobile.skills[skill_info[0].downcase] = Skill.new(cs[0], skill_info[0], skill_info[1], skill_info[2], cs[1])
      end
    end
  end

  def loadPlayerMobileData(user_id)
    user_active = @db.execute "select active_id from users where id = ?", user_id

    puts "Active: #{user_active}"

    rows = @db.execute "select id, room_id, character_id from mobiles where id = ?", user_active[0]
    if rows.count > 0
=begin      
      if !characters[rows[0][2]]
        puts "your character does not exist"
        new_row = @db.execute("select id, name, description, stat_id from characters where id = ?", rows[0][2]).first
        if new_row
          puts "but does it in the table? yes"
          stat = @db.execute "select attackspeed, damagereduction, hitpoints, manapoints, damage from stats where id = ?", new_row[3]
          stat = Hash[['attackspeed', 'damagereduction', 'hitpoints', 'manapoints', 'damage'].zip(stat[0])]
          @characters[new_row[0]] = Character.new(new_row[1], new_row[2], stat)
        end
      end
=end
      rows[0]
    else
      puts "didn't find anyone, sorry"
      nil
    end
  end

  def quit_active(mobile)
    if mobile
      @db.execute "update users set active_id=null where id=?", mobile.user_id
    end
  end

end

module MYSQL

  require 'mysql2'

  def initDB
    begin
      @db = Mysql2::Client.new(:host => "localhost", :username => "root")
      @db.query "use rdrails_development" #fix me: use env variable for this
    rescue
      puts "************************************** ALERT! ************************************"
      puts "Cannot open MYSQL Database. Cannot open MYSQL Database. Cannot open MYSQL Database."
      puts "**********************************************************************************"
    end
  end

  def loadRooms
    @rooms = {}
    rows = @db.query "select id, name, description from rooms"
    rows.each do |row|
      id = row["id"]
      exits = @db.query "select direction, destination_id from exits where room_id = #{id}"
      room_exits = {}
      exits.each do |exit|
        room_exits[exit["direction"]] = exit["destination_id"]
      end      

      @rooms[id] = Room.new(id, row["name"], row["description"], room_exits, self)
    end
  end

  def loadMobiles
    rows = @db.query "select id, room_id, character_id from mobiles where user_id is null"
    rows.each do |row|
      loadMobile(row, self)
    end
  end

  def loadMobile(mobile_info, game, user_id = nil)
    if mobile_info.nil?
      return
    end
    u = Mobile.new(mobile_info["id"], mobile_info["room_id"], game, user_id)
    if @mobiles.select { |m| m.id == mobile_info["id"] }.count <= 0
      loadInventory(u, mobile_info["character_id"])
      loadEquipment(u, mobile_info["character_id"])
      loadSkills(u, mobile_info["character_id"])
      loadCharacterInfo(u, mobile_info["character_id"])
      u.addCommands
      @mobiles.push(u)
      if user_id
        @users.push(u)
      end
    end
    u
  end

  def loadInventory(m, cid)
    items = @db.query "select item_id from inventory_items where character_id = #{cid}"
    items.each do |item|
      #puts "here", item[0], @items[item[0]]
      if @items.key?(item[0])
        m.addItem(@items[item[0]].clone)
      end
    end
  end

  def loadEquipment(m, cid)
    equipment = @db.query("select weapon_id, head_id from equipment where character_id = #{cid}").first
    if equipment
      m.equip("weapon", @items[equipment["weapon_id"]])
      m.equip("head", @items[equipment["head_id"]])
    else
      return
    end
  end
=begin
  def loadCharacters
    @characters = {}
    rows = @db.execute "select id, name, description, stat_id from characters"
    rows.each do |row|
      stat = @db.execute "select attackspeed, damagereduction, hitpoints, manapoints, damage from stats where id = ?", row[3]
      stat = Hash[['attackspeed', 'damagereduction', 'hitpoints', 'manapoints', 'damage'].zip(stat[0])]
      @characters[row[0]] = Character.new(row[1], row[2], stat)
    end
  end
=end
  def loadCharacterInfo(mobile, id)
    new_row = @db.query("select `id`, `name`, `short`, `long`, `keywords`, `description`, `level`, `experience`, `stat_id` from characters where id = #{id}").first
    if new_row
      stat = loadStat(new_row["stat_id"])
      mobile.setCharacterInfo(new_row["name"], new_row["short"], new_row["long"], new_row["keywords"], new_row["description"], new_row["level"], new_row["experience"], stat)
    end
  end
  
  def loadItems
    @items = {}
    rows = @db.query "select id, name, description, stat_id, slot, noun, level from items"
    rows.each do |row|
      stat = loadStat(row[3])
      @items[row[0]] = Item.new(row[1], row[2], stat, row[4], row[5], row[6])
    end
  end

  def loadStat(id)    
    stat = @db.query("select attackspeed, damagereduction, hitpoints, manapoints, damage, hitroll from stats where id = #{id}").first
  end

  def loadSkills(mobile, cid)
    character_skills = @db.query "select skill_id, percentage from character_skills where character_id = #{cid}"
    character_skills.each do |cs|
      skill_info = @db.query("select name, cp, level from skills where id = #{cs['skill_id']}").first
      if skill_info
        mobile.skills[skill_info['name'].downcase] = Skill.new(cs['skill_id'], skill_info['name'], skill_info['cp'], skill_info['level'], cs['percentage'])
      end
    end
  end

  def loadPlayerMobileData(user_id)
    user_active = @db.query("select active_id from users where id = #{user_id}").first

    player = @db.query("select id, room_id, character_id from mobiles where id = #{user_active['active_id']}").first
    if player
      player
    else
      puts "didn't find anyone, sorry"
      nil
    end
  end

  def quit_active(mobile)
    if mobile
      @db.query "update users set active_id=null where id=#{mobile.user_id}"
    end
  end

end