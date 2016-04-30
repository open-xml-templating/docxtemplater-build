#/usr/bin/bash

set -e
set -u

npm install -g uglify-js

uglifyversion="$(uglifyjs --version)"

echo "using : $uglifyversion"

[[ "$uglifyversion" =~ "uglify-js 2." ]] || { echo "you need version 2.x of uglifyjs"; exit 1; }

if [ ! -d src ]; then
	git clone https://github.com/open-xml-templating/docxtemplater.git src
else
	cd src
	git checkout master
	git pull
	cd ..
fi

mkdir build -p

cd src

for tag in $(git tag)
do
	cd ..
	filename="$(pwd)""/build/docxtemplater.""$tag"".js"
	minfilename="$(pwd)""/build/docxtemplater.""$tag"".min.js"
	cd src
	# Skipping versions < 1.0
	echo "$tag" | grep "v[12]" || continue
	# Skipping Already existing versions
	if [ -f "$filename" ] && [ -f "$minfilename" ]; then echo "Skipping $tag (file exists)" && continue; fi
	echo "processing $tag"
	git checkout "$tag"
	npm install
	[ -f gulpfile.js ] && gulp allCoffee
	npm test
	result=$?
	echo "result : $result"
	cd ..
	if [ "$result" == "0" ]; then
		echo "running browserify"
		startfilename="./src/js/docxgen.js"
		[ -f "$startfilename" ] || startfilename="./src/js/docxtemplater.js"
		browserify -r "$startfilename" -s Docxgen > "$filename"
		echo "running uglify"
		uglifyjs "$filename" > "$minfilename" --verbose --ascii-only
		echo "runned uglify"
	fi
	cd src
done

cd ..

# Copy latest tag to docxtemplater-latest.{min,}.js
cp "$filename" build/docxtemplater-latest.js
cp "$minfilename" build/docxtemplater-latest.min.js
