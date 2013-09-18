package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
)

const (
	tnrfile  = "tnrs.csv"
	outfile  = "exdata.csv"
	endpoint = "https://www.deich.folkebibl.no/cgi-bin/rest_service/copies/1.0-beta/data/%s?fields=full&exfields=full"
	failed   = "failed.txt" // Log for failed titlenrs
)

type jsonRes struct {
	Elements map[string]title
}

type title struct {
	Copies []ex
}

type ex struct {
	Num int
	Loc string
	Plc string
}

func main() {
	f, err := os.Open(tnrfile)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	logfile, err := os.Create(failed)
	if err != nil {
		log.Fatal(err)
	}
	defer logfile.Close()
	log.SetOutput(logfile)

	var exInfo jsonRes
	var t string
	scanner := bufio.NewScanner(f)
	fout, err := os.Create(outfile)
	if err != nil {
		log.Fatal(err)
	}

	for scanner.Scan() {
		t = scanner.Text()
		t = t[1 : len(t)-1] // strip quotes

		resp, err := http.Get(fmt.Sprintf(endpoint, t))
		if err != nil {
			fmt.Println(err)
			log.Println(t)
			continue
		}

		body, err := ioutil.ReadAll(resp.Body)
		defer resp.Body.Close()
		if err != nil {
			fmt.Println(err)
			log.Println(t)
			continue
		}

		err = json.Unmarshal(body, &exInfo)
		if err != nil {
			fmt.Println(err)
			log.Println(t)
			continue
		}

		for _, e := range exInfo.Elements[t].Copies {
			fout.WriteString(fmt.Sprintf("\"%v\",\"%v\",\"%v\",\"%v\"\n", t, e.Num, e.Loc, e.Plc))
		}
	}
}
