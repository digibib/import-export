package main

import (
	"encoding/csv"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
)

func main() {
	inFile := flag.String("i", "res_sorted.csv", "input file (CSV)")
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

	r := csv.NewReader(f)
	r.Comma = '|'

	w := csv.NewWriter(out)
	w.Comma = '|'
	defer w.Flush()

	row := make([]string, 8)
	pri := 1
	var titnr string
	for {
		row, err = r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatal(err)
		}
		if titnr == row[0] {
			pri = pri + 1
		} else {
			pri = 1
		}
		row[1] = fmt.Sprintf("%d", pri)
		titnr = row[0]

		err = w.Write(row)
		if err != nil {
			log.Fatal(err)
		}

	}
}
