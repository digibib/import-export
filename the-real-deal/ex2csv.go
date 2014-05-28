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
^
ex_titnr |16006|
ex_exnr |67|
ex_avd |fopp|
ex_plass |OSLO|
ex_hylle ||
ex_note ||
ex_bind |0|
ex_aar |0|
ex_status ||
ex_resstat ||
ex_laanstat ||
ex_utlkode ||
ex_laanr |-128115|
ex_laantid |28|
ex_forfall |00/00/0000|
ex_purrdat |00/00/0000|
ex_antpurr |0|
ex_etikett ||
ex_antlaan |24|
ex_kl_sett |0|
ex_strek |-16006|
^
*/

func parseRecord(record bytes.Buffer) []string {
	row := make([]string, 21)

	rdr := bufio.NewReader(&record)
	var i int
	for {
		_, err := rdr.ReadString('|')
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
		row[i] = strings.Replace(strings.TrimSpace(v[0:len(v)-1]), "\n", "", 1)
		i = i + 1
	}
	return row
}

func main() {
	inFile := flag.String("i", "data.exemp.20140516-042825.txt", "input file (exemp)")
	outFile := flag.String("o", "ex.csv", "output file (CSV)")
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
	for scanner.Scan() {
		line := scanner.Text()
		if line == "^" {
			row := parseRecord(b)

			// Write CSV row
			err = w.Write(row)
			if err != nil {
				log.Fatal(err)
			}

			b.Reset()

			c += 1
			fmt.Printf("%d Exemp records processed\r", c)
		} else {
			b.WriteString(line)
		}
	}
	w.Flush()
	fmt.Printf("%d Exemp records processed and written out to file: %s\n", c, out.Name())
}
