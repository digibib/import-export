#!/usr/bin/env ruby
# coding:utf-8

require 'rubygems'
require 'date'
if RUBY_VERSION < "1.9"
  require "faster_csv"
  CSV = FCSV
else
  require "csv"
end

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} -e barcodes.txt -p patronarray [-o output_file.csv]\n")
    $stderr.puts(" -b barcodes file must be on single lines\n")
    $stderr.puts(" -p [patronarray] range of patron cards in format 1000-1020 \n")
    exit(2)
end
loop { case ARGV[0]
    when '-b' then ARGV.shift; $barcode_file = ARGV.shift
    when '-p' then ARGV.shift; $patrons = ARGV.shift
    when '-o' then ARGV.shift; $output_file = ARGV.shift
    when /^-/ then usage("Unknown option: #{ARGV[0].inspect}")
    else
      if !$barcode_file || !$patrons then usage("Missing argument!\n") end
    break
end; }


patronrange = $patrons.split("-")
patronrange.length > 1 ? @patronrange = (patronrange[0].to_i..patronrange[1].to_i).to_a : @patronrange = patronrange
@barcodes    = File.readlines($barcode_file)

def time_rand from = 0.0, to = Time.now
  Time.at(from + rand * (to.to_f - from.to_f))
end

# issue time
def borrow_book(from)
  borrow = time_rand(from)
end

# return time
def return_book(issued)
  issued + (60 * 60 * 24 * rand(100))
end


def generate(from=Date.today - 7)
  actions = []
  @patronrange.each do |patron|
    rand(30..100).times do
      issued = borrow_book(from)
      returned = return_book(issued)
      barcode = "%014d" % @barcodes.sample.to_i
      actions.push(:timestamp => issued.strftime('%Y-%m-%d %I:%M:%S %T'), :action => :issue, :patroncard => patron, :barcode => barcode)
      actions.push(:timestamp => returned.strftime('%Y-%m-%d %I:%M:%S %T'), :action => :return, :patroncard => nil, :barcode => barcode) unless returned > Time.now
    end
  end
  sorted = actions.sort_by { |k| k[:timestamp] }
end

circulation = generate(Time.new("2011-01-01"))
#puts circulation
koc = "Version=1.0\tGenerator=kocQt4\tGeneratorVersion=0.1\n"
circulation.each do | item |
  koc += item[:timestamp].to_s
  koc += "\t" + item[:action].to_s
  koc += "\t" + item[:patroncard].to_s if item[:patroncard]
  koc += "\t" + item[:barcode].to_s
  koc += "\n"
end
puts koc