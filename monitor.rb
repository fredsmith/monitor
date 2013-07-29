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
   # return a loaded config object
   return YAML.load_file(file)
end

def notifyHipChat(channel, key, notification, severity)
   client = HipChat::Client.new(key)
   if severity == "critical"
      # send a red alert with the "notify" flag on critical errors
      client[channel].send('monitor', '@all ' + notification, :color => 'red', 'notify' => true, :message_format => 'text')
   elsif severity == "warning"
      # send a yellow alert without notification on warnings
      client[channel].send('monitor', notification, :color => 'yellow', :message_format => 'text')
   else 
      # send a green alert on everything else.
      client[channel].send('monitor', notification, :color => 'green', :message_format => 'text')
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
  # got the below from dashing's ruby code. gets the last result from a graphite JSON object
  result = JSON.parse(response.body, :symbolize_names => true)
  currentValue = (result.first[:datapoints].select { |el| not el[0].nil? }).last[0]
  if monitor["warning"] > monitor["critical"]
     # check to see if warning is higher than critical.  If so, we assume high is good and low is bad.
     if currentValue < monitor["critical"]
        return {'status' => "critical", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; critical = " + monitor["critical"].to_s}
     elsif currentValue < monitor["warning"]
        return {'status' => "warning", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; warning = " + monitor["warning"].to_s}
     end
  elsif monitor["warning"] < monitor["critical"]
     # if warning is lower than critical, assume low is good and high is bad.
     if currentValue > monitor["critical"]
        return {'status' => "critical", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; critical = " + monitor["critical"].to_s}
     elsif currentValue > monitor["warning"]
        return {'status' => "warning", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; warning = " + monitor["warning"].to_s}
     end
  end
  # if we made it here, everything is OK.  return a status object with some notes about the current good status, and what our thresholds are.
  return {'status' => "OK", 'message' => monitor["monitor"] + " is " + currentValue.to_s + "; warning = " + monitor["warning"].to_s + ", critical = " + monitor["critical"].to_s}
  
end

def main(configfile)
   config = parseConfig(configfile)
   config["monitors"].each do |monitor|
      # iterate through all monitor objects
      if monitor["type"] == "graphite"
         status = checkGraphite(monitor)
      else 
         # eventually more stuff can go above. shell script checks are next on the list.
         status = { 'status' => "critical", 'message' => monitor["monitor"] + " is of unknown type " + monitor["type"] }
      end
      if status["status"] != "OK"
         # got a not OK status.
         if config["notifiers"][monitor["notify"]]["type"] == "hipchat"
            # the object nesting here is really confusing.  basically look up the notifier with the same name as the notify specified in the monitor.
            # Check if it's a hipchat notifier
            # if so, send hipchat our channel name, key, the message and the status level.
            notifyHipChat(config["notifiers"][monitor["notify"]]["channel"], config["notifiers"][monitor["notify"]]["key"], status["message"], status["status"])
         elsif config["notifiers"][monitor["notify"]]["type"] == "email"
            #FIXME: write a notifyEmail function 
            #notifyEmail(status["message"], status["status"])
         end
      end
   end
end

if __FILE__ == $PROGRAM_NAME
   # main entry point of the program
   main(ARGV[0])
end
