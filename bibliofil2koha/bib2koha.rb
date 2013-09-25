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
    $stderr.puts(" -limit [limit] stops processing after given number of records\n")
    exit(2)
end

loop { case ARGV[0]
    when '-i' then ARGV.shift; $input_file = ARGV.shift
    when '-e' then ARGV.shift; $ex_file = ARGV.shift
    when '-o' then ARGV.shift; $output_file = ARGV.shift
    when '-l' then ARGV.shift; $recordlimit = ARGV.shift.to_i # force integer
    when /^-/ then usage("Unknown option: #{ARGV[0].inspect}")
    else
      if !$input_file || !$ex_file then usage("Missing argument!\n") end
    break
end; }

count = 0

# reading records from a batch file
reader = MARC::Reader.new($input_file)

# Read CSV exemplars into hash
keys = ['tnr', 'exnr','branch','loc','barcode']
exemplars = {}
CSV.foreach( File.open($ex_file) ) do | row |
  # append to Array within hash and create if new
  (exemplars[row[0].to_i] ||= []) << Hash[ keys.zip(row) ]
end

if $output_file
  writer = MARC::XMLWriter.new($output_file)
  writer.write("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
  writer.write("<collection>\n")
end

  
reader.each do | record |
  
  tnr = record['001'].value.to_i.to_s
  count += 1
  if $recordlimit then break if count > $recordlimit end

  # BUILD FIELD 942  
  if record['019']['b']

    # item type to uppercase $942c
		record['019']['b'].split(',').each do | itemtype |
      record.append(MARC::DataField.new('942', ' ',  ' ', ['c', itemtype.upcase]))
    end
  else
    record.append(MARC::DataField.new('942', ' ',  ' ', ['c', X]))
  end

  # BUILD FIELD 952   
  
  # add exemplars and holding info from csv hash
  if exemplars["tnr" => tnr] 
    exemplars[tnr].each do |copy|
      field952 = MARC::DataField.new('952', ' ',  ' ')
      field952.append(MARC::Subfield.new('a', copy["branch"]))    # owner
      field952.append(MARC::Subfield.new('b', copy["branch"]))    # holder
      field952.append(MARC::Subfield.new('c', copy["loc"]))       # location
      field952.append(MARC::Subfield.new('p', copy["barcode"]))   # barcode
      field952.append(MARC::Subfield.new('t', copy["exnr"]))      # exemplar number
      
      # item type to uppercase $952y
      if record['019']['b']
        record['019']['b'].split(',').each do | itemtype |
          field952.append(MARC::Subfield.new('y', itemtype.upcase))
        end
      else
        field952.append(MARC::Subfield.new('y', 'X'))   # dummy item type
      end
      
      record.append(field952)
    end
  end

  # BUILD FIELD 999
  record.append(MARC::DataField.new('999', ' ',  ' ', ['d', tnr]))
  if $output_file
    writer.write("\n")
    writer.write(record)
  else
    puts record
  end
end

writer.write("</collection>\n") if $output_file
 
if $output_file
  writer.close()
end
