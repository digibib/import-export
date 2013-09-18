# Konvertere bibliofilmarc til kohamarc

Tar bibliofilmarc (normarc) og mapper eksemplardata + strekkode m.m. til kohas marc21

## Perl-moduler som trengs

String::Strip
MARC::File::USMARC
MARC::File::XML
MARC::Record
File::Slurp
strict
Getopt::Long
Pod::Usage
Data::Dumper
Modern::Perl

Installeres med 
```sudo cpan -if String::Strip```

## Konvertér

perl ./bibliofil2koha.pl -i bibliofil.mrc -o koha.mrc
