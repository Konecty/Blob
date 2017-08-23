bugsnag = require("bugsnag")

if process.env.NEW_RELIC_LICENSE_KEY?
	require 'newrelic'

process.on 'uncaughtException', (err) ->
	console.log err
	console.error new Date, err

express = require 'express'
cors = require 'cors'
routes = require './routes'
path = require 'path'

app = express()

corsOptions =
	origin: new RegExp "#{process.env.CORS_ORIGIN or '.konecty.com'}$"
	credentials: true
	allowedHeaders: ['content-type', 'authorization', '_authtokenid', '_authtokenns', 'x-requested-with']

app.use cors(corsOptions)

# app.engine('html', require('ejs').renderFile);
if process.env.BUGSNAG_KEY?
	bugsnag.register(process.env.BUGSNAG_KEY)
	app.use bugsnag.requestHandler

console.log 'Port:', (process.env.PORT || 3000)
# all environments
app.set 'port', process.env.PORT || 3000

# app.use express.favicon()
app.use (req, res, next) ->
	res.on 'error', (err) ->
		console.log 'res error', err

	req.on 'error', (err) ->
		console.log 'res error', err

	# req.connection.setTimeout(10000)

	res.on 'header', () ->
		if res.statusCode isnt 200
			res.removeHeader 'Cache-Control'
			res.removeHeader 'Expires'
			res.removeHeader 'Expiration'

	logRequest = ->
		if res.statusCode isnt 200
			console.log req.headers

	res.on 'finish', logRequest
	res.on 'close', logRequest

	next()

app.use express.logger('dev')
# app.use express.bodyParser({uploadDir: './upload', defer: false})
app.use express.methodOverride()
app.use app.router
# app.use express.static(path.join(__dirname, 'public'))

app.use bugsnag.errorHandler

# development only
if 'development' == app.get('env')
	app.use express.errorHandler()

routes.init app

app.listen app.get('port'), ->
	console.log 'Express server listening on port', app.get('port')
