package main

import (
	"encoding/csv"
	"fmt"
	"log"
	"os"
	"strconv"
)

const (
	infile  = "eksemplardata.csv"
	outfile = "ex2import.csv"
)

func main() {
	fileIn, err := os.Open(infile)
	if err != nil {
		log.Fatal(err)
	}
	defer fileIn.Close()

	fileOut, err := os.Create(outfile)
	if err != nil {
		log.Fatal(err)
	}
	defer fileOut.Close()

	csvReader := csv.NewReader(fileIn)
	for {
		fields, err := csvReader.Read()
		if err != nil {
			log.Fatal(err)
		}
		titlenr, _ := strconv.Atoi(fields[0])
		exnr, _ := strconv.Atoi(fields[1])
		fileOut.WriteString(fmt.Sprintf("%v,%v,%s,\"%s\",0301%07d%03d\n", fields[0], fields[1], fields[2], fields[3], titlenr, exnr))
	}

}
