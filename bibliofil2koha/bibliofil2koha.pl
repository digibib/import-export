#!/usr/bin/perl -w

require "./Bibliofil.pm";

# You will also need to set the PERL5LIB environment variable to the directory on your 
# system that contains the C4 directory of Koha

use MARC::File::USMARC;
use MARC::File::XML;
use MARC::Record;
use File::Slurp;
use strict;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Modern::Perl;
binmode STDOUT, ":utf8";

my ($input_file, $limit, $verbose) = get_options();

# Check that the file exists
if (!-e $input_file) {
  print "The file $input_file does not exist...\n";
  exit;
}

# $/ = "\r\n";
my $c = 0;
my %encodings;

my $marcfile = MARC::File::USMARC->in($input_file);
while ( my $record = $marcfile->next() ) {

  $c++;
  
  # Check that we have a 245
  if ( !$record->field('245') ) {
    if ( $verbose ) {
      print Dumper $record, "\n";
      print "\n\n--- $c -- Missing 245 ----------------------------------\n\n";
    }
    next;
  }
  
  # Check that 245$a is not just "1"
  if ( $record->field('245') && $record->field('245')->subfield('a') && $record->field('245')->subfield('a') eq "1" ) {
    next;
  }
  
  
  ### The actual conversion
  
  my ($new_record, $converted_from, $errors_arrayref) = client_transform($record);

  # Count the conversions
  #$encodings{$converted_from}++;

  if ($verbose) { 
    print $record->as_usmarc(), "\n";
    print "---\n"; 
    print $new_record->as_formatted(), "\n";
    #if ($errors_arrayref->[0]) {
    #  print Dumper $errors_arrayref;
    #}
    print "records converted:  $c \n"; 
  } else {
    print $new_record->as_usmarc(), "\n";
  }

  if ($limit && ($c == $limit)) { last; }

}

sub get_options {

  # Options
  my $input_file = '';
  my $limit = '';
  my $verbose = '';
  my $help = '';
  
  GetOptions (
    'i|infile=s' => \$input_file, 
    'l|limit=i' => \$limit,
    'v|verbose' => \$verbose, 
    'h|?|help'  => \$help
  );

  pod2usage(-exitval => 0) if $help;
  pod2usage( -msg => "\nMissing Argument: -i, --infile required\n", -exitval => 1) if !$input_file;

  return ($input_file, $limit, $verbose);

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

=item B<-v --verbose>

Print records in mnemonic form. 

=item B<-h, -?, --help>
                                               
Prints this help message and exits.

=back
                                                               
=cut
