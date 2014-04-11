## Scripts

* `ex2csv.sh`: konverter eksemplardata til CSV, slik at det er mer håndterlig videre

* `merge.pl`: bygger inn eksemplardata i 952-feltet


## Import fra begynnelse til slutt

1. Eksportér data fra carl

  Kjør skriptet `/home/petterg/eksport.sh` på carl. Dette vil eksportere alle registerne til mappa `/usr/biblo/dumpreg `.

  Kopier alle filene i denne mappe til egen maskin:
  `scp /usr/biblo/dumpreg <username>@<host>:/your/path`

2. Konverter katalog til marcxml
   `yaz-marcdump -o marcxml -t utf8 helebasen.mrc > bib.marcxml`

4. Slå sammen katalog- og eksemplardata.

   Konvertér exemp registeret til CSV:
   `./ex2csv.sh <exemp-eksport> <ex.csv>`

   Bygg eksemplarata inn i 952-feltet:
   `perl merge.pl`

5. Importér katalogen inn i Koha før du går fra jobb/legger deg om kvelden (Tar 6-7-8 timer i min virtualbox VM)
