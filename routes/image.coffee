gm  = require 'gm'
fs  = require 'fs'
path = require 'path'
mm  = require 'mmmagic'
magic  = new mm.Magic(mm.MAGIC_MIME_TYPE)
Domain = require 'domain'
mkdirp = require 'mkdirp'
bugsnag = require 'bugsnag'
{Validator} = require 'validator'


validator = new Validator()
validator.error = (msg) ->
	this._valid = false
	this._errors ?= []
	this._errors.push msg
	return this
validator.validate = ->
	isValid = this._valid != false
	if isValid is false
		isValid = this._errors
	this._errors = []
	this._valid = undefined
	return isValid


validateKeys = (keys) ->
	acceptableKeys = ['resize', 'crop', 'extent', 'gravity', 'format', 'quality', 'background', 'watermark']
	processedKeys = []

	index = 0;

	accept = acceptableKeys.every (item) ->
		keyIndex = -1
		keys.forEach (key, ki) ->
			if key[0] is item
				keyIndex = ki

		if keyIndex is -1
			return true

		if keyIndex is index
			index++
			processedKeys.push keys[keyIndex]
			return true

		return false

	# console.log accept, keys.length is index
	if accept isnt true or keys.length isnt index
		return false

	return processedKeys


getAndProcessImage = (bucket, file, properties, req, res, next) ->
	params =
		Bucket: bucket
		Key: file

	domain = Domain.create()
	domain.on 'error', (err) ->
		if err?.statusCode?
			return res.send err.statusCode
		next err


	if properties.resize?
		validator.check(properties.resize.height, 'Property "height" for "resize" must be numueric and between 1 and 2048').isNumeric().min(1).max(2048)
		validator.check(properties.resize.width, 'Property "width" for "resize" must be numueric and between 1 and 2048').isNumeric().min(1).max(2048)
	if properties.crop?
		validator.check(properties.crop.height, 'Property "height" for "crop" must be numueric and between 1 and 2048').isNumeric().min(1).max(2048)
		validator.check(properties.crop.width, 'Property "width" for "crop" must be numueric and between 1 and 2048').isNumeric().min(1).max(2048)
	if properties.extent?
		validator.check(properties.extent.height, 'Property "height" for "extent" must be numueric and between 1 and 2048').isNumeric().min(1).max(2048)
		validator.check(properties.extent.width, 'Property "width" for "extent" must be numueric and between 1 and 2048').isNumeric().min(1).max(2048)

	validate = validator.validate()

	if validate isnt true
		return res.send 400, validate

	domain.run ->
		processImage = (data) ->

			image = null

			res.set 'LastModified', data.LastModified
			res.set 'ETag', data.ETag if data.Etag
			res.set 'Content-Type', data.ContentType

			if /image/.test(data.ContentType) is true
				image = gm data.Body
			else if /text\/html|application\/pdf/.test(data.ContentType) is true
				res.set 'Content-Type', 'image/jpeg'
				image = gm data.Body
				image.setFormat 'jpg'
			else
				res.set 'Content-Type', 'image/jpeg'
				image = gm 2048, 2048, '#cccccc'
				image.fill '#555'
				image.drawText 0, 0, data.ContentType, 'center'
				image.fontSize 400
				image.setFormat 'jpg'

			if data.ContentType is 'image/jpeg'
				image.interlace 'Line'

			image.gravity properties.gravity || 'Center'
			image.noProfile()

			if properties.resize?
				image.resize properties.resize.width, properties.resize.height, properties.resize.modifier

			if properties.crop?
				image.crop properties.crop.width, properties.crop.height

			if properties.background?
				image.background properties.background

			if properties.extent?
				image.extent properties.extent.width, properties.extent.height

			if properties.format?
				image.setFormat properties.format

			if properties.quality?
				image.quality properties.quality
			else
				image.quality 100
				image.define 'jpeg:preserve-settings'

			image.stream (err, stdout, stderr) ->
				if err?
					console.log err
					bugsnag.notify(err, {
						Request:
							req: req
							url: req.url
							headers: req.headers
					})
					return res.send 500

				stdout.pipe res
				stderr.on 'data', (err) ->
					console.error new Date, err.toString()
					console.error new Date, file, properties, data
					res.send 500


		generateTypedImage = (filePath, preprocess, callback) ->
			filePathToTypedImage = path.join path.dirname(filePath), '.'+preprocess, path.basename(filePath)

			fs.readFile filePath, (err, data) ->
				if err?
					return callback err

				magic.detect data, (err, result) ->
					if err?
						return callback err

					if /image|application\/pdf/.test(result) isnt true
						mkdirp path.dirname(filePathToTypedImage)
						image = gm(2048, 2048, '#cccccc')
							.fill('#555')
							.drawText(0, 0, result, 'center')
							.fontSize(400)
							.setFormat('jpg')
							.write filePathToTypedImage, (err) ->
								if err?
									return callback(err)
								callback()
					else

						gm(filePath).size (err, size) ->
							if err?
								return callback(err)

							percentage = 1
							width = Math.round size.width * percentage
							height = Math.round size.height * percentage

							readStream = fs.createReadStream path.join(process.env.USE_LOCAL_DISK_PATH, params.Bucket, "#{req.params.preprocess}.png")

							gm(readStream)
								.background('transparent')
								.gravity('Center')
								.resize(width, height)
								.extent(size.width, size.height)
								.toBuffer (err, buffer) ->
									if err?
										return callback(err)

									mkdirp path.dirname(filePathToTypedImage), (err) ->
										if err?
											return callback(err)

										gm(buffer)
											.in(filePath)
											.out('-gravity', 'Center')
											.mosaic()
											.write filePathToTypedImage, (err) ->
												if err?
													return callback(err)
												callback()


		getImage = (filePath, preprocess, callback) ->
			filePathToGetImage = filePath
			if preprocess?
				filePathToGetImage = path.join path.dirname(filePath), '.'+preprocess, path.basename(filePath)

			fs.stat filePathToGetImage, (err, stat) ->
				if err?
					if preprocess?
						generateTypedImage filePath, preprocess, (err) ->
							if err?
								return callback(err)
							getImage filePath, preprocess, callback
					else
						callback err
					return

				fs.readFile filePathToGetImage, (err, data) ->
					callback err, data, stat


		filePath = path.join process.env.USE_LOCAL_DISK_PATH, params.Bucket, params.Key

		getImage filePath, req.params.preprocess, (err, data, stat) ->
			if err?
				if err.code isnt 'ENOENT'
					console.error new Date, 'Error reading file', err
					bugsnag.notify(err, {
						Request:
							url: req.url
							headers: req.headers
					})

				filePath = path.join process.env.USE_LOCAL_DISK_PATH, params.Bucket, decodeURIComponent params.Key
				getImage filePath, req.params.preprocess, (err, data, stat) ->
					if err?
						if err.code isnt 'ENOENT'
							console.error new Date, 'Error reading file', err
							bugsnag.notify(err, {
								Request:
									url: req.url
									headers: req.headers
							})
						return res.send 404
					else
						callProcessImage data, stat
			else
				callProcessImage data, stat

		callProcessImage = (data, stat) ->
			magic.detect data, (err, result) ->
				if err?
					console.error new Date, 'Error detecting mime type', err

				processImage
					LastModified: stat.mtime
					ContentType: result
					Body: data


exports.restCompatibilityFrame = (req, res, next) ->
	w = req.params.width
	h = req.params.height
	bucket = "konecty.#{req.params.namespace}"
	if req.params.recordId?
		file = "#{req.params.document}/#{req.params.recordId}/#{req.params.field}/#{req.params.key}"
	else
		file = "#{req.params.document}/#{req.params.field}/#{req.params.key}"
	properties = {}

	properties.resize =
		width: w
		height: h

	properties.background = req.params.background
	properties.extent =
		width: w
		height: h

	getAndProcessImage bucket, file, properties, req, res, next


exports.restCompatibility = (req, res, next) ->
	w = req.params.width
	h = req.params.height
	bucket = "konecty.#{req.params.namespace}"
	if req.params.recordId?
		file = "#{req.params.document}/#{req.params.recordId}/#{req.params.field}/#{req.params.key}"
	else
		file = "#{req.params.document}/#{req.params.field}/#{req.params.key}"
	properties = {}

	switch req.params.type
		when 'outer'
			properties.resize =
				width: w
				height: h
				modifier: '^'

		when 'crop'
			properties.resize =
				width: w
				height: h
				modifier: '^'
			properties.crop =
				width: w
				height: h

		when 'inner'
			properties.resize =
				width: w
				height: h

		when 'force'
			properties.resize =
				width: w
				height: h
				modifier: '!'

		else
			return res.send 400, "Type #{req.params.type} does not exists"

	# image.setFormat('jpg')
	# image.quality(75)

	getAndProcessImage bucket, file, properties, req, res, next


exports.restConvert = (req, res, next) ->
	file = req.params[0]
	bucket = "konecty.#{req.params.namespace}"

	keys = req.params.keys.split(',')

	keys = keys.map (key) ->
		return key.split(':')

	keys = validateKeys keys

	if keys is false
		return res.send 500

	properties = {}

	# console.log keys
	keys.forEach (key) ->
		property = key[0]
		value = key[1]

		switch property
			when 'resize'
				v = value.split('x')
				properties.resize =
					width: v[0]
					height: v[1]
					modifier: v[2]
			when 'crop'
				v = value.split('x')
				properties.crop =
					width: v[0]
					height: v[1]
			when 'extent'
				v = value.split('x')
				properties.extent =
					width: v[0]
					height: v[1]
			when 'gravity'
				properties.gravity = value
			when 'format'
				properties.format = value
			when 'quality'
				properties.quality = value
			when 'background'
				properties.background = value
			when 'watermark'
				req.params.preprocess = value

	keys = undefined
	getAndProcessImage bucket, file, properties, req, res, next


exports.restImage = (req, res, next) ->
	if ['inner', 'crop', 'outer', 'force'].indexOf(req.params.namespace) > -1
		return res.send 404

	bucket = "konecty.#{req.params.namespace}"
	file = req.params[0]

	properties = {}

	getAndProcessImage bucket, file, properties, req, res, next
