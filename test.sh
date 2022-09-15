#!/bin/sh
echo "Output: $1.pdf"
base64 "$1" > temp1
echo "{\"name\":\"$1\",\"data\":\"" | cat - temp1 > temp2
echo "\"}" >> temp2
curl --url "http://localhost:9000/2015-03-31/functions/function/invocations" -d @temp2 | jq -r .body | base64 -d > "$1.pdf"
