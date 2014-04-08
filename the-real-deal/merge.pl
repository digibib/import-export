#!/usr/bin/env perl

use MARC::Batch;
use MARC::Record;
use MARC::Field;

use Text::CSV_XS;
use Data::Dumper;

use strict;
use warnings;

binmode(STDOUT, ":utf8");

# Generate barcode from titlenr and exnr
# my $barcode = barcode($row->[TITNR], $row->[EXNR]);
sub barcode {
	my ($tnr, $exnr) = (@_);
	sprintf("0301%07d%03d", $tnr, $exnr);
}

# Generate Koha call number (hyllesignatur)
sub callnumber {
	my ($dewey, $plass, $hylle) = (@_);
	# TODO
}

sub progress_dot {
	print ".";
}

#titnr|exnr|avd |plas|hylle|note|bind|år|status|
#28410|22  |fopp|OSLO|     |mag |0   |0 |||||-227302|28|00/00/0000|00/00/0000|0||0|0|-28410
#28151|12  |from|    |q    |93,H|0   |0 |i||||-225220|28|00/00/0000|00/00/0000|0||0|0|0

# CSV Columns
use constant {
	TITNR => 0,     # brukes til å lage barcode (952$p)
	EXNR => 1,      # 952$t
	AVD => 2,       # 952$a (homebranch) 952$b (holding branch)
	PLASS => 3,     # plassering 952$c | 952$j?
	HYLLE => 4,     # hylle 952$c | 952$j?
	NOTE => 5,      # 952$z public note
	BIND => 6,      # 952$h Volume and issue information for serial items
	AAR => 7,       #
	STATUS => 8,    # ?
	RESSTAT => 9,   # ? 952$n total holds
	LAANSTAT => 10, # ? 952$l total checkouts (incl renewals?)
	UTLKODE => 11,  # ? ikke til utlån
	LAANR => 12,    # issues.borrowernumber
	LAANTID => 13,  # mangler i koha, uttrykes av sirkulasjonsregler
	FORFALL => 14,  # issues.due_date
	PURRDAT => 15,  # purredato.. inn i en annen koha-tabell?
	ANTPURR => 16,  # antall purringer, mangler i koha?
	ETIKETT => 17,  # ?
	ANTLAAN => 18,  # ? forskjellig fra LAANSTAT?
	KL_SETT => 19,  # klasseset 952$5 restricted?
	STREK => 20,    # ?
};


my $csv = Text::CSV_XS->new ({ sep_char => "|", binary => 1 });
open my $fh, "./ex.csv" or die "ex.csv missing";

print "Building giant items hash, please wait...\n";

my $ex = {};
my $count = 0;
while ( my $row = $csv->getline ($fh) ) {
	unless ( exists $ex->{ int( $row->[TITNR] ) } ) {
		$ex->{ int( $row->[TITNR] ) } = [];
	}
	push ( $ex->{ int( $row->[TITNR] ) }, $row );
	progress_dot() if (++$count % 50000 == 0);
}

close $fh;

print "\n\nLooping through marc database, merging itemsinfo into field 952.\n\n";

my $batch = MARC::Batch->new( 'USMARC', "bib.07-04-2014.mrc");
my $record_count = 0;

 # turn off strict so process does not stop on errors
$batch->strict_off();

# output processed marc to this file
open(OUTPUT, '> out.mrc') or die $!;

while (my $record = $batch->next() ) {
	$record_count++;

	my $tnr = int( $record->field('001')->data() );

	# Add 942 field (default item type)
	if ( $record->subfield('019', 'b') ) {
		my $it = uc $record->subfield('019', 'b');
		$record->append_fields( MARC::Field->new(942, ' ', ' ', 'c' => $it) );
	} else {
		# No item type, set to 'X'
		$record->append_fields( MARC::Field->new(942, ' ', ' ', 'c' => 'X') );
	}

	# Build 952 field (eksemplardata)
	if( exists $ex->{$tnr} ) {
		foreach my $x ( @{ $ex->{$tnr} } ) {
			# 952$a branchcode
			my $field952 = MARC::Field->new('952', '', '', 'a' => @$x[AVD] );

			# 952$b holding branch (the same?)
			$field952->add_subfields('b' => @$x[AVD] );

			# 952$c shelving location (authorized value? TODO check)
			if ( @$x[PLASS] ne "" ) {
				$field952->add_subfields('c' => @$x[PLASS] );
			}

			# 952$o full call number (hylleplassering)
			# TODO skal all info med her, eks 'q' for kvartbøker i mag ?
			my $a = '';
			my $b = '';
			if ($record->field('090') && $record->field('090')->subfield('c')) {
				$a = $record->field('090')->subfield('c');
			}
			if ($record->field('090') && $record->field('090')->subfield('d')) {
				$b = ' ' . $record->field('090')->subfield('d');
			}
			$field952->add_subfields('o' => $a . $b);

			# 952$p barcode
			$field952->add_subfields('p' => barcode(@$x[TITNR], @$x[EXNR] ) );

			# 952$t copy (eksemplarnummer)
			$field952->add_subfields('t' => @$x[EXNR] );

			# 952$y item type
			if ( $record->subfield('019', 'b') ) {
				my $it = uc $record->subfield('019', 'b');
				$field952->add_subfields('y' => $it );
			} else {
				# No item type, set to 'X'
				$field952->add_subfields('y' => 'X' );
			}

			# add the complete 952 field
			$record->append_fields($field952);
		} # end ex foreach
	} else {
		warn "WARNING: No items found for titlenr: $tnr\n";
	}

	print OUTPUT $record->as_usmarc();

	#print "\n\n" . Dumper($record->field('952'));

	# Stop early for now
	last if ($record_count == 100);
}

close(OUTPUT);

print "\nNumber of records processed: $record_count";
print "\nWritten to file: out.mrc."