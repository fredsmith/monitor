monitor
=======

## About

A simple Graphite (and eventually more) alerting tool.

 - Configured via yaml
 - Scheduled via cron
 - Alerts via Hipchat

## Dependencies
   apt-get install ruby-dev
   gem install hipchat json rest-client

## Installation

check out somewhere (I checked out in /opt/) , edit the yaml file, and create the following cron entry:

    */5 * * * * /opt/monitor/monitor.rb /opt/monitor/5min.yaml

