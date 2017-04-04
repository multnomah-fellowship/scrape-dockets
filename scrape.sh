#!/bin/bash
set -euo pipefail

debug() {
  [ -n ${DEBUG:-""} ] && echo $1 || true
}

echo "Downloading docket..."
today=$(date +%Y-%m-%d)
filename="downloaded/docket-$today.pdf"
out_filename="processed/$today.csv"
debug "  $filename"
wget -q -O"$filename" http://www.mcda.us/mcda_online_docket.pdf

echo "Uploading to Tabula..."
resp=$(curl -s -F "files[]=@$filename;filename=mdca_online_docket_$today" http://127.0.0.1:8080/upload.json)
file_id=$(echo $resp | jq -r ".[].file_id")

echo -n "Getting number of pages..."
sleep 3
number_of_pages=$(curl -s "http://127.0.0.1:8080/pdfs/$file_id/pages.json" | jq length)
echo " $number_of_pages"

echo "Sending extraction coordinates..."
time=$(date +%s)
letters=(A B C D E F G H I J K L M N O P)
coords='[{"page":1,"extraction_method":"guess","selection_id":"'${letters[0]}$time'","x1":15.345,"x2":749.925,"y1":105.435,"y2":535.095,"width":734.58,"height":429.65999999999997}'
for I in $(seq 2 $number_of_pages); do
  coords=$coords',{"page":'$I',"extraction_method":"guess","selection_id":"'${letters[0]}$time'","x1":18.315,"x2":750.915,"y1":21.285,"y2":542.025,"width":732.6,"height":520.74}'
done
coords=$coords']'

curl "http://127.0.0.1:8080/pdf/$file_id/data" \
  -s \
  -d "coords=$coords" \
  -d format=csv \
  -d "new_filename=$filename" >$out_filename

echo "Deleting from Tabula..."
curl -X POST \
  -s \
  -d "_method=delete" \
  "http://127.0.0.1:8080/pdf/$file_id"

echo "Adding to git..."
git add "$filename" "$out_filename"

if git diff --cached --exit-code; then
  echo "No changed detected!"
else
  echo "Hit enter to commit and push"
  read confirm
  git commit -m "Add scraped data for $today"
fi
