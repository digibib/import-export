#!/usr/bin/perl

# This script converts bibliofil marc for import to koha

use MARC::Batch;
use MARC::Record;
use MARC::Field;
use Getopt::Long;
use Pod::Usage;
use warnings;
#use Data::Dump 'dump';

use Text::CSV_XS;
use autodie;

my ($input_file, $ex_file, $limit) = get_options();

 my @rows; # array that will store csv values

 my $csv = Text::CSV_XS->new ({ binary => 1 }) or
     die "Cannot use CSV: ".Text::CSV->error_diag ();

#open file
open my $FH, "<:encoding(utf8)", "$ex_file" or die "$ex_file: $!";

my %books;
#read file in while loop

while (my $row = $csv->getline ($FH) ) {
      #{push @rows, $row;};
      push(@{ $books{$row-> [0]} }, $row);
   }

$csv->eof or $csv->error_diag ();
close $FH;

# Check that the file exists
if (!-e $input_file) {
  print "The file $input_file does not exist...\n";
  exit;
}

my $batch = MARC::Batch->new( 'USMARC', $input_file );

# turn off strict so process does not stop on errors
$batch->strict_off();

my $rec_count = 0;

# Item types hash, used in 942c and 952y
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
    # stupid MARC::Field requires subfield on creation, so deletes immediately after
    $field942->delete_subfield('code' => 'c');                  
     
	# $942c	Koha [default] item type
  if ($record->subfield('019', 'b')) {

		foreach my $t (split(',', $record->subfield('019', 'b'))) {
      if ( exists $item_types{$t} ) {
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
	
	# Add this field to the record
	$record->append_fields($field942);
			
	# BUILD FIELD 952
  my $field952 = MARC::Field->new('952', '', '', 'a' => '');
    # stupid MARC::Field requires subfield on creation, so deletes immediately after
     $field952->delete_subfield('code' => 'a');
     
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
    
  # loop though biblio items from csv hash and populate $952 biblioitems
  if ($books{ int($field001)} ) {
    my $book = $books{ int($field001)};
    foreach my $tnr ( @{$book} ) {
      my $field952 = MARC::Field->new('952', '', '', 'a' => $tnr->[2]);   # a) owner
      $field952->add_subfields('b' => $tnr->[2]);                         # b) holder
      if ($tnr->[3] ne "") {
        $field952->add_subfields('c' => $tnr->[3]);                       # c) shelf location
      }
      $field952->add_subfields('p' => $tnr->[4]);                         # p) barcode
      $field952->add_subfields('t' => $tnr->[1]);                         # t) copy
      
      $record->append_fields($field952);
    }
  }
  
  # $999 biblioitemnumber
  
  my $field999 = MARC::Field->new('999', '', '', 'd' => int($field001) );
	$record->append_fields($field999);
  
  print $record->as_usmarc();
  
  if ($limit && ($rec_count == $limit)) { last; }
}

sub get_options {

  # Options
  my $input_file = '';
  my $ex_file = '';
  my $limit = '';
  my $help = '';
  
  GetOptions (
    'i|infile=s' => \$input_file, 
    'e|exfile=s' => \$ex_file, 
    'l|limit=i' => \$limit,
    'h|?|help'  => \$help
  );

  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;

  return ($input_file, $ex_file, $limit);

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

=item B<-e, --infile>

Name of the Items CSV file to be read.

=item B<-l, --limit>

Only process the n first records.

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut
