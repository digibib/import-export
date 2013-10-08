package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os"
)

const (
	numTitles = 60000 // actually 57301 as per 10.06.2013
	batchSize = 10000 // number of results at a time (virtuoso limit)
	endpoint  = "http://marc2rdf.deichman.no/sparql"
	filename  = "tnrs.csv"
	query     = `
				PREFIX bibo: <http://purl.org/ontology/bibo/>
				PREFIX dc: <http://purl.org/dc/terms/>

				SELECT DISTINCT ?tnr
				FROM <http://data.deichman.no/books>
				WHERE {
				?book a bibo:Document ;
				      dc:identifier ?tnr ;
				      dc:source "DFB"
				}
				OFFSET %d
				LIMIT %d
	`
)

func sparqlQuery(endpoint string, query string) ([]byte, error) {
	resp, err := http.PostForm(endpoint,
		url.Values{"query": {query}, "format": {"csv"}})
	if err != nil {
		return []byte{}, err
	}
	body, err := ioutil.ReadAll(resp.Body)
	defer resp.Body.Close()
	if err != nil {
		return []byte{}, err
	}
	return body, nil
}

func main() {
	f, err := os.Create(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	fmt.Printf("Fetching %d titlenrs and storing in %s\n", numTitles, filename)
	for t := 0; t < numTitles; t += batchSize {
		res, err := sparqlQuery(endpoint, fmt.Sprintf(query, t, batchSize))
		if err != nil {
			log.Fatal(err)
		}
		if _, err = f.WriteString(string(res)); err != nil {
			log.Fatal(err)
		}
	}

}
