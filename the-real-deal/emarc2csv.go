package main

import (
	"bufio"
	"encoding/csv"
	"flag"
	"fmt"
	"os"
	"strconv"
	"strings"
)

func main() {
	inFile := flag.String("i", "", "emarc input file")
	outFile := flag.String("o", "emarc.csv", "csv output file")
	flag.Parse()

	if *inFile == "" {
		fmt.Println("Missing parameters:")
		flag.PrintDefaults()
		os.Exit(1)
	}

	f, err := os.Open(*inFile)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer f.Close()

	out, err := os.Create(*outFile)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer out.Close()

	w := csv.NewWriter(out)
	w.Comma = '|'
	defer w.Flush()

	v := make([]string, 3)
	scanner := bufio.NewScanner(f)
	var tnr, ex string

	for scanner.Scan() {
		line := scanner.Text()

		if line == "^" {
			tnrd, err := strconv.Atoi(tnr)
			if err != nil {
				fmt.Println(err)
				os.Exit(1)
			}
			exd, err := strconv.Atoi(ex)
			if err != nil {
				fmt.Println(err)
				os.Exit(1)
			}
			v[0] = fmt.Sprintf("0301%07d%03d", tnrd, exd)

			// skip lines where neither k-fond or hyllesignatur is present
			if v[1] == "" || v[1] == "0" && v[2] == "" {
				continue
			}

			err = w.Write(v)
			if err != nil {
				fmt.Println(err)
				os.Exit(1)
			}
			v[0] = ""
			v[1] = ""
			v[2] = ""

			continue
		}

		switch line[1:4] {
		case "001":
			tnr = line[4:len(line)]
		case "002":
			ex = line[4:len(line)]
		case "016":
			if len(line) >= 9 {
				v[1] = line[8:9]
			}
		case "090":
			fields := strings.Split(line[7:len(line)], "$")
			for i := range fields {
				fields[i] = fields[i][1:len(fields[i])]
			}
			v[2] = strings.Join(fields, " ")
		}

	}

}
