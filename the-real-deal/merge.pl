#!/usr/bin/env perl

use MARC::Batch;
use MARC::Record;
use MARC::Field;
use MARC::File::XML ( BinaryEncoding => 'utf8' );

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

#titnr|exnr|avd |plas|hylle|note|bind|år|status|resstat|laanstat|utlkode|laanr  |laantid|forfall   |purrdat   |antpurr|etikett|antlaan|kl_set|strek
#28410|22  |fopp|OSLO|     |mag |0   |0 |      |       |        |       |-227302|28     |00/00/0000|00/00/0000|0      |       |0      |0     |-28410
#28151|12  |from|    |q    |93,H|0   |0 |i     |       |        |       |-225220|28     |00/00/0000|00/00/0000|0      |       |0      |0     |0

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
	RESSTAT => 9,   # 952$m antal renewals
	LAANSTAT => 10, # ? 952$l total checkouts (incl renewals?)
	UTLKODE => 11,  # ? ikke til utlån
	LAANR => 12,    # issues.borrowernumber
	LAANTID => 13,  # mangler i koha, uttrykes av sirkulasjonsregler
	FORFALL => 14,  # issues.due_date
	PURRDAT => 15,  # purredato.. inn i en annen koha-tabell?
	ANTPURR => 16,  # antall purringer, mangler i koha?
	ETIKETT => 17,  # ?
	ANTLAAN => 18,  # 952$l total checkouts
	KL_SETT => 19,  # klasseset 952$5 restricted?
	STREK => 20,    # ?
};


my $csv = Text::CSV_XS->new ({ sep_char => "|", binary => 1 });
open my $fh, "./ex.csv" or die "ex.csv missing";

print "Building items hash, please wait...\n";

my $ex = {};
while ( my $row = $csv->getline ($fh) ) {
	unless ( exists $ex->{ int( $row->[TITNR] ) } ) {
		$ex->{ int( $row->[TITNR] ) } = [];
	}
	push ( $ex->{ int( $row->[TITNR] ) }, $row );
}

close $fh;

print "\n\nLooping through marc database, merging itemsinfo into field 952.\n\n";

my $record_count = 0;
my $xmloutfile = MARC::File::XML->out( 'out.marcxml' );
my $batch = MARC::Batch->new('XML', "bib.marcxml");
$batch->strict_off();

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

			# 952$h volume and issue information, flerbindsverk?
			if ( @$x[BIND] ne "0" ) {
				$field952->add_subfields('h' => @$x[BIND] );
			}

			# 952$l total checkouts
			$field952->add_subfields('l' => @$x[ANTLAAN] );

			# 952$m total renewals
			if ( @$x[LAANSTAT] ne "" ) {
				# Antall fornyelser som en char. Første fornyelse blir "1", andre "2" osv.
				# Dersom det fornyes over 9 ganger så blir det ":", ";", "<" osv. Følger ascii-tabellen.
				my $val = ord( @$x[LAANSTAT] ) - 48;
				$field952->add_subfields('m' => $val );
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

			# 952$z public note
			if ( @$x[NOTE] ne "" ) {
				$field952->add_subfields('z' => @$x[NOTE] );
			}

			# 952$5 restricted
			if ( @$x[UTLKODE] ne "" && @$x[UTLKODE] eq "r") {
				# hvis 'r': ikke til utlån)
				$field952->add_subfields('5' =>  '1' );
			}

			# add the complete 952 field
			$record->append_fields($field952);
		} # end ex foreach
	} else {
		#warn "WARNING: No items found for titlenr: $tnr\n";
	}


	$xmloutfile->write( $record);

	# Stop early for now
	#last if ($record_count == 1000);
}

$xmloutfile->close();

print "\nNumber of records processed: $record_count";
print "\nWritten to file: out.mrc."