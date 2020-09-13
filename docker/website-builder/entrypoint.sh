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

mkdir -p /srv/jekyll/vendor/bundle
chmod -R 777 /srv/jekyll/vendor/bundle
bundle  config set path /srv/jekyll/vendor/bundle
jekyll build -d ../_site

popd

cp -v /var/run/backerei/payouts/payouts.json _site

find
# send website to google storage for website serving
#/usr/local/gcloud/google-cloud-sdk/bin/gcloud auth activate-service-account --key-file $GOOGLE_APPLICATION_CREDENTIALS

echo "now uploading site to firebase"

cat << EOF > .firebaserc
{
      "projects": {
          "default": "$FIREBASE_PROJECT"
      }
}
EOF

 /home/jekyll/.npm-global/bin/firebase deploy --token "$FIREBASE_TOKEN"

# TEMP - import old payout page manually
sleep 10000000

