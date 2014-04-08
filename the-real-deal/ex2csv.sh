#!/usr/bin/env sh
echo "Converting items file to CSV (This will take a few minutes) ..."
# Uncomment this to get column names as first row
rm -f $2
touch $2
#head -n21 $1 | cut -d ' ' -f1 | tr "\n" "|" | sed s/.$/"\n"/ > $2
sed -n 's/^[a-z_ ]*//p' $1 | tr -d "|" | tr "\n" "|" | tr "^" "\n" | sed 's/^|//g' | sed 's/|$//g' >> $2

echo "Verifying CSV quality.."
echo "The following lines has not 21 columns:"
cat $2 | awk -F"|" '{if (NF != 21) print $0}'

echo "\n"
echo "Clean the CSV manually before continuing."