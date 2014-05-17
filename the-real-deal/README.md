## Scripts

* `ex2csv.sh`: konverter eksemplardata til CSV, slik at det er mer håndterlig videre

* `merge.pl`: bygger inn eksemplardata i 952-feltet

* `line2iso.pl`: konverter fra marc linjeformat til iso

* `emarc2sql.go`: genererer diverse SQL update/insert statements (informasjon som ikke kommer med via bulkmarcimport.pl)

* `laaner2csv.go`: konverterer laaner-registeret til CSV

## Installer avhengigheter (ubuntu)

* yaz:
  `sudo apt-get install yaz`
* perl-marc:
  Hvis ikke Koha er installert trenger du noen perl-bibliotek
  `sudo apt-get install libmarc-perl libmarc-record-perl libmarc-xml-perl libswitch-perl`

## Import fra begynnelse til slutt

### Eksportér alle registere fra carl

  Kjør skriptet `/home/petterg/eksport.sh` på carl. Dette vil eksportere alle registerne til mappa `/usr/biblo/dumpreg `.

  Kopier alle registerdumpene til egen maskin:
  `scp /usr/biblo/dumpreg <username>@<host>:/your/path`

### Lånerregister

Kjør følgende for å konvertere låneregisteret til CSV slik at det kan lastes rett in i MySQL:

    go run laaner2csv -i=data.laaner.20140516-043220.txt -o=laaner.csv

Start MySql slik at du du får tilgang til lokale filer:

    mysql --local-infile=1 -u root

Last CSV fila inn i borrowers-tabellen:


```sql
LOAD DATA LOCAL INFILE '/vagrant/laaner.csv' INTO TABLE borrowers
CHARACTER SET utf8
FIELDS TERMINATED BY '|'
OPTIONALLY ENCLOSED BY '\"'
LINES TERMINATED BY '\n'
(cardnumber, surname, firstname, address, address2, zipcode, city,
country, phone, categorycode, B_address, B_zipcode, B_city,
dateofbirth, sex, borrowernotes, dateexpiry, branchcode);
```

*NB dette forutsetter at alle lånekategorikodene er på plass i categories-tabellen*, hvis ikke vil dette feile med:

```sql
ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails (`koha_knakk`.`borrowers`, CONSTRAINT `borrowers_ibfk_1` FOREIGN KEY (`categorycode`) REFERENCES `categories` (`categorycode`))
```

TODO insert statements, eller få dem inn i defaults.sql.

### Katalog og Eksemplarregister


#### 2. Konvertér katalog til marcxml

   `hoggestabe -i=data.vmarc.txt -o=bib.marcxml`

#### 3. Konvertér exemp registeret til CSV:

   `./ex2csv.sh <exemp-eksport> <ex.csv>`

   Skriptet vil liste opp eventuelle linjer som har avvikende antall kolonner. *Disse må du fjerne eller fikse manuelt før du går videre.*

#### 4. Slå sammen katalog- og eksemplardata.

   Bygg eksemplarata inn i 952-feltet:

   `perl merge.pl`

   Du vil nå ha en fil `out.marcxml` på ca 2 GB klar til import.

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
    ("LOST", "8", "tapt, regning betalt"),
    ("LOST", "9", "vidvanke, registrert forsvunnet"),
    ("LOST", "10", "retur eieravdeling (ved import"),
    ("LOST", "11", "til henteavdeling (ved import)"),
    ("NOT_LOAN", "-1", "i bestilling"),
    ("NOT_LOAN", "2", "ny"),
    ("NOT_LOAN", "3", "til internt bruk"),
    ("NOT_LOAN", "4", "til katalogisering"),
    ("NOT_LOAN", "5", "vurderes kassert"),
    ("NOT_LOAN", "6", "til retting"),
    ("NOT_LOAN", "7", "til innbinding"),
    ("RESTRICTED", "1", "begrenset tilgang"),
    ("RESTRICTED", "2", "referanseverk");
   ```

#### 6. Importér katalogen inn i Koha når du går fra jobb/legger deg om kvelden (tar laaang tid):

NB: for at tittelnummrene skal brukes som biblioitemnumber, må du `git bz apply 6113`.

  ```bash
  sudo PERL5LIB=/usr/local/src/kohaclone KOHA_CONF=/etc/koha/sites/knakk/koha-conf.xml perl /usr/local/src/kohaclone/misc/migration_tools/bulkmarcimport.pl -d -file /vagrant/out.marcxml -g 001 -v 2 -b -m=MARCXML
```
#### 7. SQL updates
Ikke all informasjon kommer med ved bulkmarcimporten. Noe trenger manuell oppdatering:

```go run emarc2sql.go -i data.emarc.20140426-140347.txt```

Dette generer noen sql-filer som kan importeres rett i databasen:

```bash
  mysql -u root koha_knakk < /vagrant/hs.sql
  mysql -u root koha_knakk < /vagrant/kfond.sql
```



#### 8. Slett "slettede poster"

Først: `git bz apply 11084`, så

    sudo PERL5LIB=/usr/local/src/kohaclone KOHA_CONF=/etc/koha/sites/knakk/koha-conf.xml perl /usr/local/src/kohaclone/misc/cronjobs/delete_fixed_field_5.pl -c

Dette vil sørge for at slettede poster (identifisert med status 'd' i leader posisjon 5) havner i `deletedbiblio` og `deletedbiblioitems` tabellene.


### Autoritetsregister

pga. unicodeprob må det gjøres i to omganger:

* konvertere fra linjeformat til marc (legger til en dummy Leader):
  `perl line2iso2.pl -i data.aut.20140425-114247.txt > data.aut.mrc`

* kovertere til ønsket format med utf8:
  `yaz-marcdump -o marcxml -t utf8 data.aut.mrc > aut.marcxml`
