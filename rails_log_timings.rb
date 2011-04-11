#!/usr/bin/env ruby

# This tool produces quick timing reports for the
# controllers and actions from Rails 2 and 3 log
# files. We are only interested in status 200.

class Stats
   def initialize
      @data = Hash.new
   end

   def add(key, value)
      if @data.has_key?(key)
         @data[key] << value.to_f
      else
         @data[key] = [value.to_f]
      end
   end

   def keys
      @data.keys.sort
   end

   def report(key)
      siz = @data[key].size
      min = @data[key].min
      avg = @data[key].inject(0.0){|a,b| a += b} / siz
      max = @data[key].max

      return siz, min, avg, max
   end

   def bucket(key, width)
      buckets = Array.new

      # Initialise the number of buckets required
      ((@data[key].max / width).to_i + 1).times{buckets << 0}

      # Fill up the buckets
      @data[key].each{|value| buckets[(value / width).to_i] += 1}

      return buckets
   end
end

total = Stats.new
view  = Stats.new
db    = Stats.new

controller = ''
action = ''

R2_P = /Processing (.*)\#([^ ]+)/
R2_C = /Completed in (\d+)ms \(View: (\d+), DB: (\d+)\) \| 200 OK/

R3_P = /Processing by (.*)\#(.*) as /
R3_C = /Completed 200 OK in (.*)ms \(Views: (.*)ms \| ActiveRecord: (.*)ms\)/

ARGF.each do |line|
   if line =~ R2_P or line =~ R3_P
      controller = $1
      action = $2
   elsif line =~ R2_C or line =~ R3_C
      key = "#{controller}##{action}"

      total.add(key, $1)
      view.add(key, $2)
      db.add(key, $3)
   end
end

t = Array.new

old_c = nil

total.keys.each do |key|
   c,a = key.split(/\#/)

   puts unless old_c == nil
   puts "Controller: #{c}" if old_c != c
   old_c = c

   puts "%25s  %5s %5s %5s %5s %5s : %s" % ['', '', 'Count', 'Min', 'Avg', 'Max', "50ms buckets"]

   puts "%25s: %5s %5d %5d %5d %5d   %s" % [ a, 'Total', *total.report(key).map{|x| x.to_i}, total.bucket(key, 50).inspect]
   puts "%25s  %5s %5d %5d %5d %5d   %s" % ['', 'View',  *view.report(key).map{|x| x.to_i},  view.bucket(key, 50).inspect]
   puts "%25s  %5s %5d %5d %5d %5d   %s" % ['', 'DB',    *db.report(key).map{|x| x.to_i},    db.bucket(key, 50).inspect]
end
