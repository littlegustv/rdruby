require './game.rb'
game = Game.new

Rails.logger = Logger.new(STDOUT)

ActionCable.server.pubsub.subscribe("server", 
  ->(command) {
    command = JSON.parse(command)
    game.command(command)
  }, 
  ->(command){
    puts "Subscribed: #{command}"
  }
)

game.run