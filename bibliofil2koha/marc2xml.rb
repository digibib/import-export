require 'marc'

# reading records from a batch file
reader = MARC::Reader.new('helebasen.fixed.mrc')
writer = MARC::XMLWriter.new('helebasen.fixed.xml')
for record in reader
  # print out field 245 subfield a
  writer.write(record)
end

# writing a record as XML
writer.close()

# encoding a record
#MARC::Writer.encode(record) # or record.to_marc
