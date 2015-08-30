#/usr/bin/bash

if [ ! -d src ]; then
	git clone https://github.com/open-xml-templating/docxtemplater.git src
else
	cd src
	git pull
	cd ..
fi

cd src

for tag in $(git tag)
do
	cd ..
	filename="$(pwd)""/build/docxtemplater.""$tag"".js"
	minfilename="$(pwd)""/build/docxtemplater.""$tag"".min.js"
	cd src
	# Skipping versions < 1.0
	echo "$tag" | grep "v1" || continue
	# Skipping Already existing versions
	if [ -f "$filename" ] && [ -f "$minfilename" ]; then echo "Skipping $tag (file exists)" && continue; fi
	echo "processing $tag"
	git checkout "$tag"
	npm install
	gulp allCoffee
	npm test
	result=$?
	cd ..
	if [ "$result" == "0" ]; then
		browserify -r ./src/js/docxgen.js -s Docxgen > "$filename"
		uglifyjs "$filename" > "$minfilename"
	fi
	cd src
done

cd ..

# Copy latest tag to docxtemplater-latest.{min,}.js
cp "$filename" build/docxtemplater-latest.js
cp "$minfilename" build/docxtemplater-latest.min.js
