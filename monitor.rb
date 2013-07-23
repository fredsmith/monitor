#! /usr/bin/env ruby


require 'rubygems'
require 'json'
require 'open-uri'
require 'yaml'
require 'hipchat'

def parseConfig(file)
   return YAML::parse(open(file).read)
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

def checkGraphite(server,target)
   #FIXME
   return true
end

def main(configfile)
   config = parseConfig(configfile)
   pp(config)
end

if __FILE__ == $PROGRAM_NAME
   main(ARGV[0])
end
