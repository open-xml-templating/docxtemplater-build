#/usr/bin/env bash

set -euo pipefail

PATH="./node_modules/.bin:$PATH"
if ! [ -d ./node_modules/.bin ]
then
	npm install
fi

uglifyversion="$(uglifyjs --version || true)"
browserifyversion="$(browserify --version || true)"

echo "using : $uglifyversion"

[[ "$uglifyversion" =~ "3." ]] || { echo "you need version 3.x of uglifyjs"; exit 1; }
[[ "$browserifyversion" =~ "16." ]] || { echo "you need version 16.x of browserify"; exit 1; }

if [ ! -d src ]; then
	git clone https://github.com/open-xml-templating/docxtemplater.git src
else
	cd src
	git reset HEAD --hard
	git checkout master
	git pull
	cd ..
fi

mkdir build -p

cd src

build(){
	echo "$PWD"
	echo "processing $tag"
	git add .
	git reset HEAD --hard
	git checkout "$tag"
	tag_without_v="$(sed -E 's/^v//g' <<<"$tag")"
	npm install --legacy-peer-deps
	[ -f gulpfile.js ] && gulp allCoffee
	npm test
	result=$?
	echo "result : $result"
	cd ..
	if [ "$result" == "0" ]; then
		echo "running browserify"
		startfilename="./src/js/docxgen.js"
		[ -f "$startfilename" ] || startfilename="./src/js/docxtemplater.js"
		browserify --global-transform aliasify -r "$startfilename" -s Docxtemplater > "$filename"
		echo "running uglify"
		uglifyjs "$filename" > "$minfilename" --verbose --ascii-only
		echo "runned uglify"
	fi
	cat bower.json | jq '.version = "'"$tag_without_v"'"' | sponge bower.json
	# Copy latest tag to docxtemplater-latest.{min,}.js
	cp "$filename" build/docxtemplater-latest.js
	cp "$minfilename" build/docxtemplater-latest.min.js
	git add .
	git commit -am "$tag"
	git tag "$tag"
}
echo "$(pwd)"

for tag in $(git tag | sort --version-sort)
do
	# Skipping versions < 1.0
	grep -E "^v[123]" <<<"$tag" || continue
	grep -E "^v3.17" <<<"$tag" && continue
	echo "$tag"
	cd ..
	filename="$(pwd)/build/docxtemplater.$tag.js"
	minfilename="$(pwd)/build/docxtemplater.$tag.min.js"
	cd src
	# Skipping Already existing versions
	if [ -f "$filename" ] && [ -f "$minfilename" ]; then echo "Skipping $tag (file exists)" && continue; fi
	build
	cd src
done
