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
es_titnr |33985|
res_koenr |106|
res_exnr |10|
res_stat |r|
res_laanr |130|
res_dat |02/09/2013|
res_forfall |02/09/2014|
res_flerb |0|
res_bind |0|
res_avd |hbar:hsko|
res_hentavd |hsko|
res_glob |x|
res_forrige |33985|
res_neste |33985|
res_ant |1|
^

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

func orNULL(s string) string {
	if s == "" {
		return `\N`
	}
	return s
}

func main() {
	inFile := flag.String("i", "data.res.20140603-042058.txt", "input file (res)")
	outFile := flag.String("o", "res.csv", "output file (CSV)")
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
	row := make([]string, 8)
	for scanner.Scan() {
		line := scanner.Text()
		if line == "^" {
			rec := parseRecord(b)

			// biblionumber
			row[0] = rec["res_titnr"]

			// priority
			row[1] = rec["res_koenr"]

			// copynumber (needed to find itemnumber)
			if rec["res_exnr"] != "0" {
				row[2] = rec["res_exnr"]
			}

			// status
			switch rec["res_stat"] {
			case "i":
				row[3] = "W" // hentehylle
			case "y":
				row[3] = "T" // på vei til henteavdeling
			}

			// borrowernumber
			row[4] = rec["res_laanr"]

			// reservedate
			d, err := time.Parse(noDateFormat, rec["res_dat"])
			if err != nil {
				println(err.Error())
			} else {
				row[5] = d.Format(mysqlDateFormat)
			}

			// exiprationdate
			if rec["res_forfall"] != "00/00/0000" {
				d, err := time.Parse(noDateFormat, rec["res_forfall"])
				if err != nil {
					println(err.Error())
				} else {
					row[6] = d.Format(mysqlDateFormat)
				}
			}

			// branchcode
			row[7] = rec["res_hentavd"]

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
			fmt.Printf("%d Reserves processed\r", c)
		} else {
			b.WriteString(line)
		}
	}
	w.Flush()
	fmt.Printf("%d Reserve records processed and written out to file: %s\n", c, out.Name())
}
