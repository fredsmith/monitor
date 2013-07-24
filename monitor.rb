#! /usr/bin/env ruby


require 'rubygems'
require 'json'
require 'open-uri'
require 'yaml'
require 'hipchat'
require 'pp'
require "rest-client"
require "json"

def parseConfig(file)
   return YAML.load_file(file)
end

def notifyHipChat(notification, severity)
   client = HipChat::Client.new('5fbda24fff6c2a2921b7ea4199aeb9')
   if severity == "critical"
      client['General'].send('monitor', notification, :color => 'red', notify => true)
   elsif severity == "warning"
      client['General'].send('monitor', notification, :color => 'yellow')
   else 
      client['General'].send('monitor', notification, :color => 'green')
   end
end


def checkGraphite(monitor)
  url = monitor["server"] + "/render?format=json&target=" + monitor["target"] + "&from=-10min"
  response = RestClient.get(url)
  result = JSON.parse(response.body, :symbolize_names => true)
  currentValue = (result.first[:datapoints].select { |el| not el[0].nil? }).last[0].round(2)
  #if monitor["warning"] > monitor["critical"]
  print currentValue
end

def main(configfile)
   config = parseConfig(configfile)
   #puts config.inspect
   config["monitors"].each do |monitor|
      print monitor["monitor"] + ": "
      if monitor["type"] == "graphite"
         checkGraphite(monitor)
      elsif monitor["type"] == "shell"
         print "shell"
      else 
         print "unknown"
      end
      print "\n"
   end
end

if __FILE__ == $PROGRAM_NAME
   main(ARGV[0])
end
