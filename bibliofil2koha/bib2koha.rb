#!/usr/bin/env ruby
# coding:utf-8

require 'rubygems'
require 'marc'
if RUBY_VERSION < "1.9"
  require "faster_csv"
  CSV = FCSV
else
  require "csv"
end

def usage(s)
    $stderr.puts(s)
    $stderr.puts("Usage: \n")
    $stderr.puts("#{File.basename($0)} -i input_file.mrc [-e ex_file.csv -o output_file.csv -r recordlimit]\n")
    $stderr.puts(" -i input_file must be MARC binary\n")
    $stderr.puts(" -e exemplar file must be CSV\n")
    $stderr.puts(" -o output_file file must be xml file\n")
    $stderr.puts(" -l [limit] stops processing after given number of records\n")
    $stderr.puts(" -r [limit] pick random records with limit (random skipping)\n")
    exit(2)
end
loop { case ARGV[0]
    when '-i' then ARGV.shift; $input_file = ARGV.shift
    when '-e' then ARGV.shift; $ex_file = ARGV.shift
    when '-o' then ARGV.shift; $output_file = ARGV.shift
    when '-l' then ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when '-r' then ARGV.shift; $randomize = ARGV.shift.to_i # force integer
    when /^-/ then usage("Unknown option: #{ARGV[0].inspect}")
    else
      if !$input_file then usage("Missing argument!\n") end
    break
end; }

def createRandomNumbers
  return nil unless $randomize
  totalrecords = 410000
  # create a random skip interval
  i = 0
  randominterval = totalrecords / $randomize * 2

  $randomize.times { @randomNumbers.push( i+= rand(randominterval) )}
end

def createExamplars
  # Read CSV @exemplars into hash
  keys = ['tnr', 'exnr','branch','loc','barcode']
  CSV.foreach( File.open($ex_file) ) do | row |
    # append to Array within hash and create if new
    (@exemplars[row[0].to_i] ||= []) << Hash[ keys.zip(row) ]
  end
end

def processRecord(record)

  tnr = record['001'].value.to_i

  # BUILD FIELD 942
  if record['019'] && record['019']['b']
    # item type to uppercase $942c
    record.append(MARC::DataField.new('942', ' ',  ' ', ['c', record['019']['b'].upcase ]))
  else
    record.append(MARC::DataField.new('942', ' ',  ' ', ['c', 'X']))
  end

  # BUILD FIELD 952

  # add @exemplars and holding info from csv hash
  if @exemplars && @exemplars[tnr]
    @exemplars[tnr].each do |copy|
      field952 = MARC::DataField.new('952', ' ',  ' ')
      field952.append(MARC::Subfield.new('a', copy["branch"]))    # owner
      field952.append(MARC::Subfield.new('b', copy["branch"]))    # holder
      field952.append(MARC::Subfield.new('c', copy["loc"]))       # location
      field952.append(MARC::Subfield.new('p', copy["barcode"]))   # barcode
      field952.append(MARC::Subfield.new('t', copy["exnr"]))      # exemplar number

      # item type to uppercase $952y
      if record['019'] && record['019']['b']
        field952.append(MARC::Subfield.new('y', record['019']['b'].upcase))
      else
        field952.append(MARC::Subfield.new('y', 'X'))   # dummy item type
      end

      # set item callnumber
      if record['090'] && record['090']['c']
        field952.append(MARC::Subfield.new('o', record['090']['c']))
      end

      record.append(field952)
    end
  end

  # BUILD FIELD 999
  record.append(MARC::DataField.new('999', ' ',  ' ', ['d', tnr.to_s]))

  @currentRecord = @randomNumbers.shift if @randomNumbers
  record
end

####
# INIT
####

if $randomize
  @randomNumbers = []
  createRandomNumbers
  puts @randomNumbers
  @currentRecord = @randomNumbers.shift
end

if $ex_file
  @exemplars = {}
  createExamplars
end

count = 0

# reading records from a batch file
reader = MARC::Reader.new($input_file)
#reader = MARC::Reader.new($input_file, :external_encoding => "binary")

####
# PROCESS RECORDS
####

if $output_file
  output = File.open($output_file, "w+")
  output << "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
  output << "<collection>\n"
end

reader.each do | item |

  count += 1

  # skip until next random no
  if $randomize
    next unless count == @currentRecord
  end

  # decrease limit counters and stop when it reaches 0
  if $randomize
    break if ($randomize -= 1) <= 0
  elsif $recordlimit
    break if ($recordlimit -= 1) <= 0
  end

  # ok - go ahead!

  record = processRecord(item)

  if $output_file
    output << record.to_xml
    output << "\n"
  else
    puts record.to_xml
  end

end

output << "</collection>\n" if $output_file
