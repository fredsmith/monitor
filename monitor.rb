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

def notifyHipChat(channel, key, notification, severity)
   client = HipChat::Client.new(key)
   if severity == "critical"
      client[channel].send('monitor', notification, :color => 'red', 'notify' => true)
   elsif severity == "warning"
      client[channel].send('monitor', notification, :color => 'yellow')
   else 
      client[channel].send('monitor', notification, :color => 'green')
   end
end


def checkGraphite(monitor)
  # takes a monitor hash and returns a status hash
  url = monitor["server"] + "/render?format=json&target=" + monitor["target"] + "&from=-2h"
  begin
     response = RestClient.get(url)
  rescue => error
     #catch errors with graphite or misconfigured checks.
     return { 'status' => "critical", 'message' => monitor["monitor"] + ": " + url + " returned an error" }
  end
  result = JSON.parse(response.body, :symbolize_names => true)
  currentValue = (result.first[:datapoints].select { |el| not el[0].nil? }).last[0]
  if monitor["warning"] > monitor["critical"]
     if currentValue < monitor["critical"]
        return {'status' => "critical", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; critical = " + monitor["critical"].to_s}
     elsif currentValue < monitor["warning"]
        return {'status' => "warning", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; warning = " + monitor["warning"].to_s}
     end
  elsif monitor["warning"] < monitor["critical"]
     if currentValue > monitor["critical"]
        return {'status' => "critical", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; critical = " + monitor["critical"].to_s}
     elsif currentValue > monitor["warning"]
        return {'status' => "warning", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; warning = " + monitor["warning"].to_s}
     end
  end
  return {'status' => "OK", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; warning = " + monitor["warning"].to_s + ", critical = " + monitor["critical"].to_s}
  
end

def main(configfile)
   config = parseConfig(configfile)
   #puts config.inspect
   config["monitors"].each do |monitor|
      #print monitor["monitor"] + ": "
      if monitor["type"] == "graphite"
         status = checkGraphite(monitor)
      else 
         status = { 'status' => "critical", 'message' => monitor["monitor"] + " is of unknown type " + monitor["type"] }
      end
      if status["status"] != "OK"
         if config["notifiers"][monitor["notify"]]["type"] == "hipchat"
            notifyHipChat(config["notifiers"][monitor["notify"]]["channel"], config["notifiers"][monitor["notify"]]["key"], status["message"], status["status"])
         elsif config["notifiers"][monitor["notify"]]["type"] == "email"
            notifyEmail(status["message"], status["status"])
         end
      end
   end
end

if __FILE__ == $PROGRAM_NAME
   main(ARGV[0])
end
