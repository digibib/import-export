package main

import (
	"bufio"
	"encoding/csv"
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
)

const MaxRecords = 400

func explode(marcfield string) map[string]string {
	m := make(map[string]string)
	for _, pair := range strings.Split(marcfield, "$") {
		id, val := pair[0:1], pair[1:len(pair)]
		m[id] = val
	}
	return m
}

func orNULL(s string) string {
	if s == "" {
		return "NULL"
	}
	return s
}

func main() {
	inFile := flag.String("i", "data.lmarc.20140520-104911.txt", "input file (lmarc)")
	outFile := flag.String("o", "lmarc.sql", "output file (sql)")
	flag.Parse()

	if *inFile == "" || *outFile == "" {
		fmt.Println("Missing parameters:")
		flag.PrintDefaults()
		log.Fatal("exiting")
	}

	in, err := os.Open(*inFile)
	if err != nil {
		log.Fatal(err)
	}
	defer in.Close()

	out, err := os.Create(*outFile)
	if err != nil {
		log.Fatal(err)
	}
	defer out.Close()

	w := csv.NewWriter(out)
	w.Comma = '|'

	scanner := bufio.NewScanner(in)

	c := 0
	row := make([]string, 9)

	for scanner.Scan() {
		line := scanner.Text()
		if line == "^" {
			// Set nullable columns to NULL when they contain empty string
			for i := range row {
				row[i] = orNULL(row[i])
			}

			// Write CSV row
			err = w.Write(row)
			if err != nil {
				log.Fatal(err)
			}

			fmt.Printf("%v\n", row)

			c = c + 1
			if c == MaxRecords {
				break
			}

			for i := range row {
				row[i] = ""
			}
			continue
		}

		// parse content
		switch line[1:4] {
		case "001": // lånenummer
			lnr, err := strconv.Atoi(line[4:len(line)])
			if err != nil {
				log.Printf("cannot parse borrowernumber: %v\n", line)
				continue
			}
			row[0] = fmt.Sprintf("%d", lnr)
		case "105": // foresatte
			fields := explode(line[4:len(line)])
			row[1] = fields["a"] // borrowers.borrowernumber
			// TODO umulig å splitte i firstname+lastname p.g.a ulik formatering:
			//   *105  $aCecilie Gudmestad (ped. leder)
			//   *105  $amor Ingeborg Neumann 11223345
			//   *105  $av/Ina Kolderup
			//   *105  $aHolt, Stine
			//   *105  $aTherese Tordhol
		case "140": // låners avdeling
			fields := explode(line[4:len(line)])
			row[2] = fields["a"] // borrowers.branchcode
		// TODO $b=foretrukken henteavdeling (som regel lik $a, men ikke alltid)
		case "150": // melding
			fields := explode(line[4:len(line)])
			// feltet er repeterbart; trekkes sammen til en streng
			// TODO kan løses bedre
			row[3] = row[3] + fields["b"] + " " // borrowers.borrowernotes
		case "190": // fødselsnummer
			// TODO skal dette ligge i klartekst?
			fields := explode(line[4:len(line)])
			row[4] = fields["a"] // ???
		case "200": // sjekk postadresse
			fields := explode(line[4:len(line)])
			if fields["s"] == "1" {
				row[5] = "1" // borrowers.gonenoaddress
			}
		case "240": // telefonnr (repeterbart felt)
			fields := explode(line[4:len(line)])
			// $c = fax|jobb|mobil|mobilsms
			switch fields["c"] {
			case "jobb":
				row[6] = fields["a"] // borrowers.phonepro
			case "mobil":
				row[7] = fields["a"] // borrowers.mobile
			case "mobilsms":
				row[8] = fields["a"] // borrowers.smsalertnumber
			}

		}

	}

}
