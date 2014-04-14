## Scripts

* `ex2csv.sh`: konverter eksemplardata til CSV, slik at det er mer håndterlig videre

* `merge.pl`: bygger inn eksemplardata i 952-feltet


## Import fra begynnelse til slutt

#### 1. Eksportér data fra carl

  Kjør skriptet `/home/petterg/eksport.sh` på carl. Dette vil eksportere alle registerne til mappa `/usr/biblo/dumpreg `.

  Kopier alle filene i denne mappe til egen maskin:
  `scp /usr/biblo/dumpreg <username>@<host>:/your/path`

#### 2. Konvertér katalog til marcxml

   `yaz-marcdump -o marcxml -t utf8 helebasen.mrc > bib.marcxml`

#### 3. Konvertér exemp registeret til CSV:

   `./ex2csv.sh <exemp-eksport> <ex.csv>`

   Skriptet vil liste opp eventuelle linjer som har avvikende antall kolonner. *Disse må du fjerne eller fikse manuelt før du går videre.*

#### 4. Slå sammen katalog- og eksemplardata.

   Bygg eksemplarata inn i 952-feltet:

   `perl merge.pl`

   Du vil nå ha en fil `out.marcxml` på ca 2 GB klar til import.

   Skriptet vil også produsere 2 CSV-filer (TODO):

   * `issues.csv` - aktive lån

   * `transfers.csv` - overføringer (til henteavdeling, retur eieraveling)

#### 5. Sett opp autoriserte verdier i Koha:
   ```sql
   DELETE FROM authorised_values WHERE category IN ("WITHDRAWN", "LOST", "NOT_LOAN", "RESTRICTED", "DAMAGED");
   INSERT INTO authorised_values (category, authorised_value, lib) VALUES
    ("WITHDRAWN", "1", "trukket tilbake"),
    ("DAMAGED", "1", "skadet"),
    ("LOST", "1", "tapt"),
    ("LOST", "2", "regnes som tapt"),
    ("LOST", "3", "tapt og erstattet"),
    ("LOST", "4", "ikke på plass"),
    ("LOST", "5", "påstatt levert"),
    ("LOST", "6", "påstått ikke lånt"),
    ("LOST", "7", "borte i transport"),
    ("NOT_LOAN", "-1", "i bestilling"),
    ("NOT_LOAN", "1", "referanseverk"),
    ("NOT_LOAN", "2", "ny"),
    ("NOT_LOAN", "3", "til internt bruk"),
    ("NOT_LOAN", "4", "til katalogisering"),
    ("NOT_LOAN", "5", "vurderes kassert"),
    ("NOT_LOAN", "6", "til retting"),
    ("NOT_LOAN", "7", "til innbinding"),
    ("RESTRICTED", "1", "begrenset tilgang");
   ```

#### 6. Importér katalogen inn i Koha når du går fra jobb/legger deg om kvelden:

  ```bash
  sudo PERL5LIB=/usr/local/src/kohaclone KOHA_CONF=/etc/koha/sites/knakk/koha-conf.xml perl /usr/local/src/kohaclone/misc/migration_tools/bulkmarcimport.pl -d -file /vagrant/out.marcxml -g 001 -v 2 -b -m=MARCXML
```
