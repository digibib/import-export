package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"strings"
)

func parseRecord(record bytes.Buffer) (string, string, error) {
	rdr := bufio.NewReader(&record)
	var lnr, epost string
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
		if strings.TrimSpace(k[0:len(k)-1]) == "lnel_nr" {
			lnr = strings.TrimSpace(v[0 : len(v)-1])
		}
		if strings.TrimSpace(k[0:len(k)-1]) == "lnel_epost" {
			epost = strings.TrimSpace(v[0 : len(v)-1])
			if epost == "" {
				return "", "", errors.New("mangler epost")
			}
		}
	}
	return lnr, epost, nil
}

func main() {
	inFile := flag.String("i", "data.lnel.20140516-144030.txt", "input file (lnel)")
	outFile := flag.String("o", "lnel.sql", "output file (sql)")
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

	scanner := bufio.NewScanner(in)
	var b bytes.Buffer

	w := bufio.NewWriter(out)
	defer w.Flush()

	for scanner.Scan() {
		line := scanner.Text()

		if line == "^" {
			lnr, epost, err := parseRecord(b)
			if err != nil {
				b.Reset()
				continue
			}

			w.WriteString(fmt.Sprintf("UPDATE borrowers SET email='%s' WHERE borrowernumber='%s';\n", epost, lnr))
			b.Reset()

		} else {
			b.WriteString(line)
		}

	}

}
