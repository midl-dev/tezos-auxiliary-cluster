#!/bin/bash
set -e

mkdir website_archive
pushd website_archive
wget -qO- $WEBSITE_ARCHIVE |  tar xvz 
popd

mv $(find website_archive/ -mindepth 1 -type d | head -1) website

rm -rvf website_archive

mkdir website/payouts

cp -v /var/run/backerei/payouts/payouts.json .

python3 /createPayoutPages.py /payouts.md $(pwd)/website/payouts

pushd website

jekyll build -d ../_site

popd

cp -v /var/run/backerei/payouts/payouts.json _site

find

# send website to google storage for website serving
/usr/local/gcloud/google-cloud-sdk/bin/gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS

echo "now rsyncing _site to $WEBSITE_BUCKET_URL"

/usr/local/gcloud/google-cloud-sdk/bin/gsutil rsync -R -d _site $WEBSITE_BUCKET_URL
