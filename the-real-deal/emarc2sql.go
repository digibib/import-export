package main

import (
	"bufio"
	"errors"
	"flag"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	KFONDUPDATE = "UPDATE items SET booksellerid = 'kulturfond' WHERE barcode = '%s';\n"
	HSUPDATE    = "UPDATE items SET itemcallnumber = '%s' WHERE barcode = '%s';\n"
	ACTIVELOANS = "UPDATE issues a INNER JOIN items b ON a.itemnumber = b.itemnumber SET branchcode ='%s', issuedate='%s' WHERE b.biblioitemnumber = '%d' AND b.copynumber ='%d';\n"
)

func explode(marcfield string) map[string]string {
	m := make(map[string]string)
	for _, pair := range strings.Split(marcfield, "$") {
		id, val := pair[0:1], pair[1:len(pair)]
		m[id] = val
	}
	return m
}

func dateFormat(m map[string]string) (string, error) {
	// MYSQL format: 2014-05-14 11:53:00

	days, ok := m["a"]
	if !ok {
		return "", errors.New("mangler utlaansdato")
	}

	tid, ok := m["t"]
	if !ok {
		return "", errors.New("mangler utlaanstidspunkt")
	}
	if len(tid) == 5 {
		tid = "0" + tid
	}

	daysd, err := strconv.Atoi(days)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	hourd, err := strconv.Atoi(tid[0:2])
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	mind, err := strconv.Atoi(tid[2:4])
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	secd, err := strconv.Atoi(tid[4:6])
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	//  func Date(year int, month Month, day, hour, min, sec, nsec int, loc *Location) Time
	t := time.Date(1900, 01, 01, hourd, mind, secd, 00, time.UTC).Add(time.Hour * 24 * time.Duration(daysd))
	return t.Format("2006-01-02 15:04:05"), nil
}

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

	outLoans, err := os.Create("loans.sql")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer outLoans.Close()

	wl := bufio.NewWriter(outLoans)
	defer wl.Flush()

	vk := make([]string, 2)  // k-fond kolonner
	vhs := make([]string, 2) // hyllesignatur kolonner
	var lm map[string]string // aktive lån

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

			if lm != nil {
				// Ignorer "Depotlaan" TODO finnes det andre typer?
				//if lm["l"] != "Depotlaan" {
				branch, ok := lm["c"]
				if !ok {
					fmt.Printf("Aktivt lån på titnr: %d ex: %d mangler utlånsavdeling, settes til 'hutl'\n", tnrd, exd)
					branch = "hutl"
				}
				d, err := dateFormat(lm)
				if err != nil {
					fmt.Printf("Aktivt lån på titnr: %d ex: %d mangler utlånsdato, hopper over\n", tnrd, exd)
				} else {
					_, err := wl.WriteString(fmt.Sprintf(ACTIVELOANS, branch, d, tnrd, exd))
					if err != nil {
						fmt.Println(err)
						os.Exit(1)
					}
				}
				//}
			}

			// reset
			vk[0] = ""
			vk[1] = ""
			vhs[0] = ""
			vhs[1] = ""
			lm = nil

			continue
		}

		switch line[1:4] {
		case "001": // titelnr
			tnr = line[4:len(line)]
		case "002": // eksnr
			ex = line[4:len(line)]
		case "016": // kulturfond
			if len(line) >= 9 {
				vk[1] = line[8:9]
			}
		case "090": // hyllesignatur
			fields := strings.Split(line[7:len(line)], "$")
			for i := range fields {
				fields[i] = fields[i][1:len(fields[i])]
			}
			vhs[1] = strings.Join(fields, " ")
		case "100": // aktivt lån
			lm = explode(line[7:len(line)])
		}

	}

}
