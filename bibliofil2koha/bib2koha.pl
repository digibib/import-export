#!/usr/bin/perl

# This script converts bibliofil marc for import to koha

use MARC::Batch;
use MARC::Record;
use MARC::Field;
use Getopt::Long;
use Pod::Usage;

my ($input_file, $limit) = get_options();

# Check that the file exists
if (!-e $input_file) {
  print "The file $input_file does not exist...\n";
  exit;
}

my $batch = MARC::Batch->new( 'USMARC', $input_file );

# turn off strict so process does not stop on errors
$batch->strict_off();

my $rec_count = 0;

my %item_types = (
  "ab" =>  "Atlas",
  "ee" =>  "DVD",
  "ed" =>  "Videotape",
  "ef" =>  "Blu-ray_Disk",
  "vo" =>  "File_folder",
  "gg" =>  "Blu-ray_Disk",
  "ge" =>  "Web_page",
  "gd" =>  "CD_ROM",
  "gc" =>  "DVD-ROM",
  "gb" =>  "Floppy_disk",
  "ga" =>  "Computer_file",
  "ic" =>  "Microfiche",
  "ib" =>  "Microfilm_reel",
  "gi" =>  "Nintendo_optical_disc",
  "gt" =>  "DTbook",
  "na" =>  "Portable_Document_Format",
  "j" =>  "Periodical_literature",
  "dj" =>  "Spoken_word_recording",
  "dh" =>  "Language_course",
  "di" =>  "Audiobook",
  "dg" =>  "Music",
  "dd" =>  "Digi_book",
  "de" =>  "Digi_card",
  "db" =>  "Compact_Cassette",
  "dc" =>  "Compact_Disc",
  "da" =>  "Gramophone_record",
  "dz" =>  "MP3",
  "ff" =>  "Photography",
  "fm" =>  "Poster",
  "a" =>  "Map",
  "c" =>  "Sheet_music",
  "b" =>  "Manuscript",
  "ma" =>  "Personal_computer_game",
  "mc" =>  "Playstation_3_game",
  "mb" =>  "Playstation_2_game",
  "h" =>  "Physical_body",
  "mo" =>  "Nintendo_Wii_game",
  "mn" =>  "Nintendo_DS_game",
  "l" =>  "Book",
  "mj" =>  "Xbox_360_game",
  "sm" =>  "Magazine",
  "fd" =>  "Reversal_film" 
);

# Da loop!
while (my $record = $batch->next()) {

  $rec_count++;
  
  #get all 000s
  my $field001 = $record->field('001')->data();

  my $field942 = MARC::Field->new(942, ' ', ' ', 'c' => '');
     $field942->delete_subfield('code' => 'c');
     
	# c	Koha [default] item type
  if ($record->subfield('019', 'b')) {

		foreach my $t (split(',', $record->subfield('019', 'b'))) {
      if ( exists $item_types{$t} ) {
        #print "$item_types{$t}\n";
        $field942->add_subfields('c' => $item_types{$t});
      }
    }
	} else {
    $field942->add_subfields('c' => 'X');
  }
	
	# k	Call number prefix
	if ($record->field('090') && $record->field('090')->subfield('c')) {
		my $field090c = $record->field('090')->subfield('c');
		$field942->add_subfields('k' => $field090c); 
	}
	# m	Call number suffix
	if ($record->field('090') && $record->field('090')->subfield('d')) {
		my $field096d = $record->field('090')->subfield('d');
		$field942->add_subfields('m' => $field096d); 
	}
	
		# 2	Source of classification or shelving scheme
	# Values are in class_sources.cn_source
	# See also 952$2
	# If 096a starts with three digits we count this as dcc-based scheme
	if ($record->field('090') && $record->field('090')->subfield('c')) {
	  my $field096c = $record->field('090')->subfield('c');
	  if ($field096c =~ m/^[0-9]{3,}.*/) {
	    $field942->add_subfields('2' => 'ddc');
	  } else {
	    $field942->add_subfields('2' => 'z');
	  }
	}
	# 6	Koha normalized classification for sorting
	
	# Add this field to the record
	$record->append_fields($field942);
			
	# BUILD FIELD 952
	
  if ($record->field('850')) {
    my @field850s = $record->field('850');
    my $itemcounter = 1;
    foreach my $field850 (@field850s) {
    
      # Comments below are from 
      # http://wiki.koha-community.org/wiki/Holdings_data_fields_%289xx%29
    
      # Create field 952, with a = "Permanent location"
      # Authorized value: branches
      # owning library
      # Code must be defined in System Administration > Libraries, Branches and Groups
      my $field850a = '';
      if ($field850->subfield('a')) {
        $field850a = $field850->subfield('a');
      } else {
        next;
      }
      my $field952 = MARC::Field->new('952', '', '', 'a' => $field850a);
  
      # Get more info for 952, and add subfields
          
      # b = Current location
      # Authorized value: branches
      # branchcode	 
      # holding library (usu. the same as 952$a )
      $field952->add_subfields('b' => $field850a);
          
      # c = Shelving location
      $field952->add_subfields('c' => 'GEN');
        
      # o = Full call number 
      my $firstpart = '';
      my $secondpart = '';
      if ($record->field('090') && $record->field('090')->subfield('c')) {
        $firstpart = $record->field('090')->subfield('c');
      }
      if ($record->field('090') && $record->field('090')->subfield('d')) {
        $secondpart = ' ' . $record->field('090')->subfield('d');
      }
      # Assemble the call number
      $field952->add_subfields('o' => $firstpart . $secondpart);
      
      
      # p = Barcode
      # Get the 7 first difits from 001

      my $titlenumber = substr $field001, 0, 7;
      # Assemble the barcode
      $field952->add_subfields('p' => '0301' . $titlenumber . sprintf("%03d", $itemcounter));
  
      # t = Copy number	
      if ($itemcounter) {
            $field952->add_subfields('t' => $itemcounter);
      }
  
      $itemcounter++;
    
      # FIXME Dummy default, for now
      $field952->add_subfields('y' => 'X');
      
      # 2 = Source of classification or shelving scheme
      # cn_source
      # Values are in class_source.cn_source
      # See also 942$2
      # If 090c starts with three digits we count this as dcc-based scheme
      if ($record->field('090') && $record->field('090')->subfield('c')) {
        my $field096a = $record->field('090')->subfield('c');
        if ($field096a =~ m/^[0-9]{3,}.*/) {
          $field952->add_subfields('2' => 'ddc');
        } else {
          $field952->add_subfields('2' => 'z');
        }
      }
    
      # Add this 952 field to the record
      $record->append_fields($field952);
    
    } # End of field $850 iteration
  
  } else {
  
    # No $850? create dummy
    
    my $field952 = MARC::Field->new('952', '', '', 'a' => 'fdum', 'b' => 'fdum'); 
    
    # Add this 952 field to the record
    $record->append_fields($field952);
  }  
  
  # $999 biblioitemnumber
  
  my $field999 = MARC::Field->new('999', '', '', 'd' => int($field001) );
	$record->append_fields($field999);
  
  print $record->as_usmarc();
  
  if ($limit && ($rec_count == $limit)) { last; }
}

#print "\n$rec_count records processed\n";
#print "----------------------------\n";
# make sure there weren't any problems.
#if ( my @warnings = $batch->warnings() ) {
#       print "\nWarnings were detected!\n", @warnings;
#   }

sub get_options {

  # Options
  my $input_file = '';
  my $limit = '';
  my $help = '';
  
  GetOptions (
    'i|infile=s' => \$input_file, 
    'l|limit=i' => \$limit,
    'h|?|help'  => \$help
  );

  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;

  return ($input_file, $limit);

}

__END__

=head1 NAME
    
bibliofil2koha.pl - Simple move from bib to koha posts
        
=head1 SYNOPSIS
            
./bibliofil2koha.pl -i records.mrc > fixed.mrc
               
=head1 OPTIONS
              
=over 4
                                                   
=item B<-i, --infile>

Name of the MARC file to be read.

=item B<-l, --limit>

Only process the n first records.

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut
