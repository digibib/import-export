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

@patronrange = (1001..1018).to_a
@barcodes    = File.readlines("500barcodes.txt")

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