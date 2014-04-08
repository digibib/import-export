#!/usr/bin/env perl

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

#28410|22  |fopp|OSLO|     |mag|0|0|||||-227302|28|00/00/0000|00/00/0000|0||0|0|-28410
#28151|12  |from|    |q    |93,H|0|0|i||||-225220|28|00/00/0000|00/00/0000|0||0|0|0
#titnr|exnr|avd |plas|hylle|note
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
	unless ( exists $ex->{$row->[TITNR]} ) {
		$ex->{$row->[TITNR]} = [];
	}
	push ( $ex->{$row->[TITNR]}, $row );
	progress_dot() if (++$count % 50000 == 0);
}

close $fh;
