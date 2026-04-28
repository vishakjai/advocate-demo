# frozen_string_literal: true

desc "Start an interactive console with files in lib loaded"
task :console do
  require 'pry'
  Dir.glob('./lib/**/*.rb').each { |f| require f }
  Pry.start
end
