package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"strconv"
	"strings"
)

const (
	KFONDUPDATE = "UPDATE items SET booksellerid = 'kulturfond' WHERE barcode = '%s';\n"
	HSUPDATE    = "UPDATE items SET itemcallnumber = '%s' WHERE barcode = '%s';\n"
)

func main() {
	inFile := flag.String("i", "", "emarc input file")
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

	outKfond, err := os.Create("kfond.sql")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer outKfond.Close()

	wk := bufio.NewWriter(outKfond)
	defer wk.Flush()

	outHs, err := os.Create("hs.sql")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer outHs.Close()

	whs := bufio.NewWriter(outHs)
	defer whs.Flush()

	vk := make([]string, 2)  // k-fond kolonner
	vhs := make([]string, 2) // hyllesignatur kolonner

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

			if vk[1] == "1" {
				vk[0] = fmt.Sprintf("0301%07d%03d", tnrd, exd)
				_, err = wk.WriteString(fmt.Sprintf(KFONDUPDATE, vk[0]))
				if err != nil {
					fmt.Println(err)
					os.Exit(1)
				}
			}

			if vhs[1] != "" {
				vhs[0] = fmt.Sprintf("0301%07d%03d", tnrd, exd)
				_, err = whs.WriteString(fmt.Sprintf(HSUPDATE, vhs[1], vhs[0]))
				if err != nil {
					fmt.Println(err)
					os.Exit(1)
				}
			}

			// reset
			vk[0] = ""
			vk[1] = ""
			vhs[0] = ""
			vhs[1] = ""

			continue
		}

		switch line[1:4] {
		case "001":
			tnr = line[4:len(line)]
		case "002":
			ex = line[4:len(line)]
		case "016":
			if len(line) >= 9 {
				vk[1] = line[8:9]
			}
		case "090":
			fields := strings.Split(line[7:len(line)], "$")
			for i := range fields {
				fields[i] = fields[i][1:len(fields[i])]
			}
			vhs[1] = strings.Join(fields, " ")
		}

	}

}
