package main

import (
	"bufio"
	"bytes"
	"encoding/csv"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"time"
)

/*
^                              borrowers table:
ln_nr |14|                     cardnumber (TODO borrowernumber PK, mangler kortnr)
ln_navn |Bla, bla |            surname, firstname
ln_adr1 |Cgt. 3|               address
ln_adr2 ||                     address2
ln_post |0658 OSLO|            zipcode, city
ln_land |no|                   country
ln_sprog ||                    -
ln_tlf |53196088|              phone
ln_kat |v|                     categorycode (FK categories)
ln_arbg |Deichmanske bibliote| - arbeidsgiver?
ln_altadr |Solørgt. 3|         B_address
ln_altpost |0658 OSLO|         B_zipcode, B_city
ln_foedt |19/12/1942|          dateofbirth (YYYY-MM-DD)
ln_kjoenn |k|                  sex (m/k/u el tom, koha bruker m/f el n/a(tom))
ln_friobs ||                   ?
ln_obs ||                      ?
ln_regnsendt |00/00/0000|      -
ln_melding ||                  borrowernotes
ln_kortdato |00/00/0000|       - (evt dateenrolled)
ln_sistelaan |15/05/2014|      -
ln_sperres |00/00/0000|        dateexpiry
ln_antlaan |13|                -
ln_antpurr |0|                 -
ln_alt_id ||                   ?

CSV columns:
cardnumber, surname, firstname, address, address2, zipcode, city,
country, phone, categorycode, B_address, B_zipcode, B_city,
dateofbirth, sex, borrowernotes, dateexpiry

*/

const (
	noDateFormat    = "02/01/2006"
	mysqlDateFormat = "2006-01-02"
)

func parseRecord(record bytes.Buffer) map[string]string {
	m := make(map[string]string, 24)

	rdr := bufio.NewReader(&record)
	for {
		k, err := rdr.ReadString('|')
		if err != nil {
			if err == io.EOF {
				break
			}
			log.Fatal(err)
		}
		v, err := rdr.ReadString('|')
		if err != nil {
			if err == io.EOF {
				break
			}
			log.Fatal(err)
		}
		m[strings.TrimSpace(k[0:len(k)-1])] = strings.Replace(
			strings.TrimSpace(v[0:len(v)-1]), "\n", "", 1)
	}
	return m
}

func main() {
	inFile := flag.String("i", "data.laaner.20140516-043220.txt", "input file (laanereg)")
	outFile := flag.String("o", "laaner.csv", "output file (CSV)")
	flag.Parse()

	if *inFile == "" || *outFile == "" {
		fmt.Println("Missing parameters:")
		flag.PrintDefaults()
		os.Exit(1)
	}

	f, err := os.Open(*inFile)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	out, err := os.Create(*outFile)
	if err != nil {
		log.Fatal(err)
	}
	defer out.Close()

	w := csv.NewWriter(out)
	w.Comma = '|'

	scanner := bufio.NewScanner(f)
	var b bytes.Buffer
	c := 0
	row := make([]string, 18)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "^" {
			rec := parseRecord(b)

			// slettede eller endrede lånere har ln_navn som begynner på '!!'
			// hopp over disse
			if strings.HasPrefix(rec["ln_navn"], "!!") {
				b.Reset()
				continue
			}

			//fmt.Printf("%v\n\n", rec)

			// 1: cardnumber
			row[0] = rec["ln_nr"]

			// 2, 3: surname, firstname
			names := strings.Split(rec["ln_navn"], ",")
			row[1] = strings.TrimSpace(names[0])
			if len(names) >= 2 {
				row[2] = strings.TrimSpace(names[1])
			}

			// 4: address
			row[3] = rec["ln_adr1"]

			// 5: address2
			row[4] = rec["ln_adr2"]

			// 6, 7: zipcode, city
			// TODO mye grums i data her, bruke regex for postnummer? /[0-9]{4}/
			zipcity := strings.SplitN(rec["ln_post"], " ", 2)
			if len(zipcity) >= 1 {
				row[5] = strings.TrimSpace(zipcity[0])
			}
			if len(zipcity) == 2 {
				row[6] = strings.TrimSpace(zipcity[1])
			}

			// 8: country
			row[7] = rec["ln_land"]

			// 9: phone
			row[8] = rec["ln_tlf"]

			// 10: categorycode
			if rec["ln_kat"] == "" {
				// TODO ukjent lånertype, hvilken kode skal de få?
				rec["ln_kat"] = "zzz"
			}
			row[9] = strings.ToUpper(rec["ln_kat"])

			// 11: B_address
			row[10] = rec["ln_altadr"]

			// 12, 13: B_zipcode, B_city
			bzipcity := strings.SplitN(rec["ln_altpost"], " ", 2)
			if len(bzipcity) >= 1 {
				row[11] = strings.TrimSpace(bzipcity[0])
			}
			if len(bzipcity) == 2 {
				row[12] = strings.TrimSpace(bzipcity[1])
			}

			// 14: dateofbirth
			dob, err := time.Parse(noDateFormat, rec["ln_foedt"])
			if err != nil {
				row[13] = ""
			} else {
				row[13] = dob.Format(mysqlDateFormat)
			}

			// 15: sex
			switch rec["ln_kjoenn"] {
			case "k":
				row[14] = "M" // male
			case "m":
				row[14] = "F" // female
			default:
				row[14] = "" // no answer
			}

			// 16: borrowernotes
			row[15] = rec["ln_melding"]

			// 17: expiry
			if rec["ln_sperres"] != "00/00/000" {
				expiry, err := time.Parse(noDateFormat, rec["ln_sperres"])
				if err != nil {
					row[16] = ""
				} else {
					row[16] = expiry.Format(mysqlDateFormat)
				}
			}

			// 18: branchcode
			// TODO alle låner må tilhøre en avdeling i Koha
			//      kanskje ligger denne informasjonen i lmarc?
			//      setter til 'hutl' foreløbig
			row[17] = "hutl"

			// Write CSV row
			err = w.Write(row)
			if err != nil {
				log.Fatal(err)
			}

			//fmt.Printf("%v\n", row)

			b.Reset()
			row[2] = ""  // clear firstname for next iteration of loop
			row[5] = ""  // clear zipcode
			row[6] = ""  // clear city
			row[11] = "" // clear B_zipcode
			row[12] = "" // clear B_city

			c += 1
			if c == 100 {
				fmt.Printf("%d Patron records processed and written out to file: %s\n", c, out.Name())
				break
			}
		} else {
			b.WriteString(line)
		}
	}
	w.Flush()
}
