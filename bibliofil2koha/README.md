# Konvertere bibliofilmarc til kohamarc

Tar bibliofilmarc (normarc) samt eksemplardata i csv og mapper eksemplardata + strekkode m.m. til kohas marc21

## Perl-moduler som trengs

String::Strip
MARC::File::USMARC
MARC::File::XML
MARC::Record
MARC::Batch
File::Slurp
strict
Getopt::Long
Pod::Usage
Modern::Perl

Installeres med 
```sudo cpan -if String::Strip```

## Konvertér

perl ./bib2koha.pl -i bibliofil.mrc -e exdata.csv > koha.mrc
