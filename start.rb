require 'redis'
require 'connection_pool'
require 'json'
require 'thread'
require './behavior.rb'
require './basic_commands.rb'
require './thief_commands.rb'
require './room.rb'
require './skill.rb'
require './character.rb'
require './item.rb'
require './mobile.rb'
require './game.rb'

# creates a connection pool which keeps calls to redis from blocking
REDIS = ConnectionPool.new(size: 10) { Redis.new }

# $game is a GLOBAL game object, required because incoming messages
# are handled on a different thread than everything else...
$game = Game.new(REDIS)

puts 'started'

Thread.abort_on_exception = true
# so does using a thread here
Thread.new do
  REDIS.with do |redis|
    redis.subscribe 'server' do |on|
      
      on.message do |channel, msg|
        data = JSON.parse(msg)
        if data['message'] == 'login'
          $game.login data['user']
        elsif data['message'] == 'logout'
          $game.logout data['user']
        else
          if (u = $game.user(data['user']))
            u.command(data)
          elsif (u = $game.login data['user'])
            u.command(data)
          else
            # nothing
          end
        end
      end

    end
  end
end

# this is the main game loop, although the logic actually happens in
# $game.update
start_t = Time.now
loop {
  next_t = Time.now
  dt = next_t - start_t
  start_t = next_t
  $game.update(dt)
  sleep 1.0 / 10
}

puts "end"