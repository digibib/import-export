#!/usr/bin/env perl

use MARC::Batch;
use MARC::Record;
use MARC::Field;
use MARC::File::XML ( BinaryEncoding => 'utf8' );

use Text::CSV_XS;
use Data::Dumper;

use Switch;
use strict;
use warnings;

binmode( STDOUT, ":utf8" );

# Generate barcode from titlenr and exnr
# my $barcode = barcode($row->[TITNR], $row->[EXNR]);
sub barcode {
    my ( $tnr, $exnr ) = (@_);
    sprintf( "0301%07d%03d", $tnr, $exnr );
}

# Generate Koha call number (hyllesignatur)
sub callnumber {
    my ( $dewey, $plass, $hylle ) = (@_);

    # TODO
}

#titnr|exnr|avd |plas|hylle|note|bind|år|status|resstat|laanstat|utlkode|laanr  |laantid|forfall   |purrdat   |antpurr|etikett|antlaan|kl_set|strek
#28410|22  |fopp|OSLO|     |mag |0   |0 |      |       |        |       |-227302|28     |00/00/0000|00/00/0000|0      |       |0      |0     |-28410
#28151|12  |from|    |q    |93,H|0   |0 |i     |       |        |       |-225220|28     |00/00/0000|00/00/0000|0      |       |0      |0     |0

# CSV Columns
use constant {
    TITNR    => 0,     # brukes til å lage barcode (952$p)
    EXNR     => 1,     # 952$t
    AVD      => 2,     # 952$a (homebranch) 952$b (holding branch)
    PLASS    => 3,     # plassering 952$c | 952$j?
    HYLLE    => 4,     # hylle 952$c | 952$j?
    NOTE     => 5,     # 952$z public note
    BIND     => 6,     # 952$h Volume and issue information for serial items
    AAR      => 7,     #
    STATUS   => 8,     # ?
    RESSTAT  => 9,     # 952$m antal renewals
    LAANSTAT => 10,    # ? 952$l total checkouts (incl renewals?)
    UTLKODE  => 11,    # ? ikke til utlån
    LAANR    => 12,    # issues.borrowernumber
    LAANTID  => 13,    # mangler i koha, uttrykes av sirkulasjonsregler
    FORFALL  => 14,    # issues.due_date
    PURRDAT  => 15,    # purredato.. inn i en annen koha-tabell
    ANTPURR  => 16,    # antall purringer på aktivt lån, mangler i koha
    ETIKETT  => 17,    # etikettpulje
    ANTLAAN  => 18,    # 952$l total checkouts
    KL_SETT  => 19,    # antall ex i klasseset
    STREK    => 20,    # gammelt felt for strekkode
};

my $csv = Text::CSV_XS->new( { sep_char => "|", binary => 1 } );
open my $fh, "./ex.csv" or die "ex.csv missing";

print "Building items hash, please wait...\n";

my $ex = {};
while ( my $row = $csv->getline($fh) ) {
    unless ( exists $ex->{ int( $row->[TITNR] ) } ) {
        $ex->{ int( $row->[TITNR] ) } = [];
    }
    push( $ex->{ int( $row->[TITNR] ) }, $row );
}

close $fh;

print
  "\n\nLooping through marc database, merging itemsinfo into field 952.\n\n";

my $record_count = 0;
my $xmloutfile   = MARC::File::XML->out('out.marcxml');
my $batch        = MARC::Batch->new( 'XML', "bib.marcxml" );
$batch->strict_off();

open( my $missing, '>', 'missing.txt' ) or die;

while ( my $record = $batch->next() ) {
    $record_count++;

    my $tnr = int( $record->field('001')->data() );

    # Add 942 field (default item type)
    if ( $record->subfield( '019', 'b' ) ) {
        my $it = uc $record->subfield( '019', 'b' );
        $record->append_fields( MARC::Field->new( 942, ' ', ' ', 'c' => $it ) );
    }
    else {
        # No item type, set to 'X'
        $record->append_fields( MARC::Field->new( 942, ' ', ' ', 'c' => 'X' ) );
    }

    # Build 952 field (eksemplardata)
    if ( exists $ex->{$tnr} ) {
        foreach my $x ( @{ $ex->{$tnr} } ) {

            my $branch = @$x[AVD];

            # Import will fail if there is no branch
            if ( $branch eq "" ) {
                $branch = "ukjent";
            }

            # 952$a branchcode
            my $field952 = MARC::Field->new( '952', '', '', 'a' => $branch );

            # 952$b holding branch (the same for now, possibly depot)
            $field952->add_subfields( 'b' => $branch );

            # 952$c shelving location (authorized value? TODO check)
            if ( @$x[PLASS] ne "" ) {
                $field952->add_subfields( 'c' => @$x[PLASS] );
            }

            # 952$h volume and issue information, flerbindsverk?
            # Vises som "publication details" i grensesnittet. (Serienummererering/kronologi)
            if ( @$x[BIND] ne "0" ) {
                $field952->add_subfields( 'h' => @$x[BIND] );
            }

            # 952$l total checkouts
            $field952->add_subfields( 'l' => @$x[ANTLAAN] );

            # 952$m total renewals
            if ( @$x[LAANSTAT] ne "" ) {

            # Antall fornyelser som en char. Første fornyelse blir "1", andre "2" osv.
            # Dersom det fornyes over 9 ganger så blir det ":", ";", "<" osv. Følger ascii-tabellen.
            my $val = ord( @$x[LAANSTAT] ) - 48;
            $field952->add_subfields( 'm' => $val );
            }

            # 952$o full call number (hyllesignatur)
            # TODO skal all info med her, eks 'q' for kvartbøker i mag ?
            my ( $a, $b, $c, $d );
            if ( $record->field('090') ) {
                if ( $record->field('090')->subfield('a') ) {
                    $a = $record->field('090')->subfield('a');
                }
                if ( $record->field('090')->subfield('b') ) {
                    $b = $record->field('090')->subfield('b');
                }
                if ( $record->field('090')->subfield('c') ) {
                    $c = $record->field('090')->subfield('c');
                }
                if ( $record->field('090')->subfield('d') ) {
                    $d = $record->field('090')->subfield('d');
                }
                my @cn = ( $a, $b, $c, $d );
                $field952->add_subfields(
                    'o' => join( " ", grep defined, @cn ) );
            }

            # 952$p barcode
            $field952->add_subfields( 'p' => barcode( @$x[TITNR], @$x[EXNR] ) );

            # 952$q due date (if checked out)
            if ( @$x[FORFALL] ne "00/00/0000" ) {
                my $date = @$x[FORFALL];
                my $y    = substr( $date, 6, 4 );
                my $m    = substr( $date, 3, 2 );
                my $d    = substr( $date, 0, 2 );
                $field952->add_subfields( 'q' => "$y-$m-$d" );
            }

            # 952$t copy (eksemplarnummer)
            $field952->add_subfields( 't' => @$x[EXNR] );

            # 952$y item type
            if ( $record->subfield( '019', 'b' ) ) {
                my $it = uc $record->subfield( '019', 'b' );
                $field952->add_subfields( 'y' => $it );
            }
            else {
                # No item type, set to 'X'
                $field952->add_subfields( 'y' => 'X' );
            }

            # 952$z public note
            if ( @$x[NOTE] ne "" ) {
                $field952->add_subfields( 'z' => @$x[NOTE] );
            }

            # eksemplarstatuser
            # forutsetter at Koha har autoriserte verdier som dokumenter i README.md

            if ( @$x[UTLKODE] ne ""
                && ( @$x[UTLKODE] eq "r" || @$x[UTLKODE] eq "e" ) )
            {

                # referanseverk: ikke til utlån
                $field952->add_subfields( '7' => '1' );
            }

            switch ( @$x[STATUS] ) {

                # NOT_LOAN ####

                # i bestilling
                case "e" { $field952->add_subfields( '7' => '-1' ); }

                # ny
                case "n" { $field952->add_subfields( '7' => '2' ); }

                # til internt bruk
                case "c" { $field952->add_subfields( '7' => '3' ); }

                # til katalogisering
                case "k" { $field952->add_subfields( '7' => '4' ); }

                # vurderes kassert
                case "v" { $field952->add_subfields( '7' => '5' ); }

                # retting
                case "q" { $field952->add_subfields( '7' => '6' ); }

                # til innbinding
                case "b" { $field952->add_subfields( '7' => '7' ); }


                # LOST #####

                # tapt
                case "t" { $field952->add_subfields( '1' => '1' ); }

                # tapt, regning betalt
                case "S" { $field952->add_subfields( '1' => '8' ); }

                # ikke på plass
                case "i" { $field952->add_subfields( '1' => '4' ); }

                # påstått levert
                case "p" { $field952->add_subfields( '1' => '5' ); }

                # påstått ikke lånt
                case "k" { $field952->add_subfields( '1' => '6' ); }

                # borte i transport
                case "v" { $field952->add_subfields( '1' => '7' ); }

                # på vidvanke
                case "V" { $field952->add_subfields( '1' => '9' ); }

            }

            # add the complete 952 field
            $record->append_fields($field952);
        }    # end ex foreach
    }
    else {
        # Ingen eksemplarer tilknyttet posten
        my $status = substr( $record->leader(), 5, 1 );
        if (   $status ne "d"
            && $status ne "f"
            && $status ne "e"
            && $status ne "i"
            && $status ne "l" )
        {
            print $missing "$tnr\n";
        }
    }

    $xmloutfile->write($record);

    # Stop early for now
    #last if ( $record_count == 10000 );

    print "$record_count records processed\r";
}

$xmloutfile->close();
close($missing);


print "\nNumber of records processed: $record_count";
print "\nWritten to file: out.marcxml."
