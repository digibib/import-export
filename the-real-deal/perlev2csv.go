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
)

/*
plev_kode |ABM|
plev_navn |ABM-utvikling|
plev_post |0033 Oslo|
plev_land |no|
plev_tlf |23 11 75 00|
plev_fax ||
plev_transport |b|
plev_sprog |nor|
plev_rabatt |0.000000|
plev_adr1 |{Postboks 8145 Dep}|
plev_adr2 ||
plev_epost ||
plev_url ||
plev_kontakt ||
plev_note ||
^

*/

func parseRecord(record bytes.Buffer) map[string]string {
	m := make(map[string]string, 15)

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

func orNULL(s string) string {
	if s == "" {
		return `\N`
	}
	return s
}

func main() {
	inFile := flag.String("i", "data.perlev.20140801-074131.txt", "input file (res)")
	outFile := flag.String("o", "perlev.csv", "output file (CSV)")
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
	c := 0            // count nr of records
	var postal string // all address lines
	curly := strings.NewReplacer("{", "", "}", "")
	row := make([]string, 12)

	for scanner.Scan() {
		line := scanner.Text()
		if line == "^" {
			rec := parseRecord(b)

			postal = ""

			// name
			row[0] = rec["plev_navn"]

			// address1
			// stripping curly braces (TCL residue)
			postal = curly.Replace(rec["plev_adr1"])
			row[1] = postal

			// address2
			row[2] = rec["plev_post"]
			if rec["plev_post"] != "" {
				postal = postal + " / "
				postal = postal + rec["plev_post"]
			}

			// address3
			row[3] = curly.Replace(rec["plev_adr2"])
			if rec["plev_adr2"] != "" {
				postal = postal + " / "
				postal = postal + row[3]
			}

			// address4
			row[4] = rec["plev_land"]
			if rec["plev_land"] != "" {
				postal = postal + " / "
				postal = postal + rec["plev_land"]
			}

			// postal (all address lines combined)
			if strings.HasPrefix(postal, " /") {
				postal = ""
			}
			row[5] = postal

			// phone
			row[6] = rec["plev_tlf"]

			// booksellerfax
			row[7] = rec["plev_fax"]

			// bookselleremail
			row[8] = rec["plev_epost"]

			// url
			row[9] = rec["plev_url"]

			// contact
			row[10] = rec["plev_kontakt"]

			// note
			row[11] = rec["plev_kode"]

			// Set nullable columns to NULL when they contain empty string
			for i := range row {
				row[i] = orNULL(row[i])
			}

			// Write CSV row
			err = w.Write(row)
			if err != nil {
				log.Fatal(err)
			}

			//fmt.Printf("%v\n", row)

			b.Reset()
			for i := range row {
				row[i] = ""
			}

			c += 1
			fmt.Printf("%d Leverandører processed\r", c)
		} else {
			b.WriteString(line)
		}
	}
	w.Flush()
	fmt.Printf("%d Leverandør records processed and written out to file: %s\n", c, out.Name())
}
