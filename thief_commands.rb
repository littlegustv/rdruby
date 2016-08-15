module ThiefCommands
  def self.extended(mod)
    mod.class_commands.push *(["backstab", "peer", "peek", "hide", "dirtkick", "rub", "steal"] & mod.skills.keys)
  end

  def cmd_backstab(args)
    if (target = target_mobile(args) || @combat)
      if target.get_percentage < 40
        emit "They are hurt and suspicious, you can't sneak up."
        return 0
      elsif start_combat(target)
        do_hit("backstab", false, {hitroll: 2, damage: 20})
        return 1
      end
    else
      emit "Backstab who?"
    end
    return 0
  end

  def cmd_peer(args)
    if (target = target_exit(args))
      emit "You peer #{target[0]}:<br>" + target[1].render(self)
      return 0.4
    else
      emit "There is no exit in that direction."
      return 0
    end
  end

  def cmd_peek(args)
    if (target = target_mobile(args))
      skill("Peek") do |success|
        if success
          emit "You get a look at what they're carrying:<br>" + target.inventory.map(&:name).join("<br>")
        else
          emit "You could not get a glimpse."
        end
        return 0.4
      end
    else
      emit "You don't see them here."
      return 0
    end
  end

  def cmd_hide(args)
    if @combat
      emit "You are too busy fighting to do that!"
      return 0
    else
      skill("Hide") do |success|
        success ? addBehavior(Hide) : emit("You failed.")
      end
    end
    return 1
  end

  def cmd_dirtkick(args)
    if (target = target_mobile(args) || @combat)
      if start_combat(target)
        if target.hasBehavior("Dirtkick")
          emit "They are already blinded."
          return 0
        else
          skill("Dirtkick") do |success|
            success ? target.addBehavior(Dirtkick) : emit("You get your feet dirty.")
          end
          return 1
        end
      end
    end
    return 0
  end

  def cmd_rub(args)
    if hasBehavior("Dirtkick")
      skill ("Rub") do |success|
        success ? removeBehavior("Dirtkick") : emit("You rub your eyes, but nothing happens.")
      end
      return 1
    else
      emit "Your eyes are fine, thanks."
      return 0
    end
  end

  def cmd_steal(args)
    if args.count <= 0
      emit "Steal what from whom?"
      return 0
    elsif args.count <= 1
      emit "Steal from whom?"
      return 0
    elsif (target_m = target_mobile(args[1]))
      if (target_i = target_item(args[0], target_m.inventory))
        if check_combat(target_m)
          skill("Steal") do |success|
            if success
              @inventory.push(target_m.inventory.delete(target_i))
              emit "Success! You steal #{target_i.render(self)} from #{target_m.render(self)}!"
            else
              emit "You have been caught stealing!"
              target_m.emit "#{render(target_m)} is a thief!  Kill them!"
              start_combat(target_m, false)
            end
          end
          return 1
        else
          return 0
        end
      else
        emit "They aren't carrying that."
        return 0
      end
    else
      emit "You can't find them."
      return 0
    end
  end

end