# Dependencies

```
apt-get install npm make graphicsmagick g++ git html2ps
npm install nave -g
nave usemain 0.10.21
npm install pm2 coffee-script -g
npm install
```

# Environment variables

* `CORS_ORIGIN` - domain origin used for CORS (default `.konecty.com`)
* `KONECTY_HOST` - Konecty host to report uploads
* `USE_LOCAL_DISK_PATH` - Local path for file storage

* `AWS_KEY` - AWS Key for storing files on S3
* `AWS_SECRET` - AWS Secret for storing files on S3

* `BUGSNAG_KEY` - key used for Bugsnag integration

## Newrelic configuration (optional)

* `NEW_RELIC_APP_NAME` - App name
* `NEW_RELIC_LICENSE_KEY` - License key
* `NEW_RELIC_LOG_LEVEL` - Log level
* `NEW_RELIC_CAPTURE_PARAMS` - Capture params
* `NEW_RELIC_ENABLED` - Enabled


# Start Command

`pm2 start pm2.json`
