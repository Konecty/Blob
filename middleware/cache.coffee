module.exports = (req, res, next) ->
	date = new Date
	date.setSeconds 31536000
	date = date.toUTCString()

	# res.set 'Cache-Control', 'public, max-age=31536000'
	res.set 'Cache-Control', 'max-age=31536000'
	res.set 'Expires', date
	res.set 'Expiration', date

	next()